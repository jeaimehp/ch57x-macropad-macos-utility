import SwiftUI
import os

/// M1: headless --selftest support + app entry.
@main
struct MicroPadStudioApp: App {
    init() {
        let args = CommandLine.arguments
        if args.contains("--selftest") {
            Self.runSelftest(args: args)   // exits process
        }
        if args.contains("--layout-test") {
            Self.runLayoutTest(args: args) // exits process
        }
        FileHandle.standardOutput.write(Data("MICROPADSTUDIO_LAUNCHED pid=\(ProcessInfo.processInfo.processIdentifier)\n".utf8))
    }

    var body: some Scene {
        WindowGroup("MicroPad Studio") {
            ContentView()
                .frame(minWidth: 980, minHeight: 540)
        }
    }

    /// Headless verification of M1 logic without UI:
    ///   MicroPadStudio --selftest <mapping.yaml>
    /// Steps: parse YAML → re-emit → CLI validate. Never uploads.
    static func runSelftest(args: [String]) -> Never {
        guard let idx = args.firstIndex(of: "--selftest"), idx + 1 < args.count else {
            FileHandle.standardError.write(Data("usage: --selftest <mapping.yaml>\n".utf8))
            exit(2)
        }
        let path = args[idx + 1]
        do {
            let text = try String(contentsOfFile: path, encoding: .utf8)
            let parsed = try MappingYAML.parse(text)
            let emitted = MappingYAML.emit(parsed)
            print("SELFTEST parse ok: model=\(parsed.model) \(parsed.rows)x\(parsed.columns) knobs=\(parsed.knobs) layers=\(parsed.layers.count)")
            // Re-parse emitted output → must equal original (round-trip invariant)
            let reparsed = try MappingYAML.parse(emitted)
            guard reparsed == parsed else {
                print("SELFTEST FAIL: round-trip mismatch\n\(emitted)")
                exit(1)
            }
            print("SELFTEST round-trip ok")
            // M2: model-level edit (what the editor's assign() ultimately does)
            var edited = parsed
            if !edited.layers.isEmpty {
                if !edited.layers[0].buttons.isEmpty,
                   !edited.layers[0].buttons[0].isEmpty {
                    edited.layers[0].buttons[0][0] = "cmd-shift-q"
                }
                if !edited.layers[0].knobs.isEmpty {
                    edited.layers[0].knobs[0].press = "mute"
                }
            }
            let editedYAML = MappingYAML.emit(edited)
            let reEdited = try MappingYAML.parse(editedYAML)
            guard reEdited == edited else {
                print("SELFTEST FAIL: edit round-trip mismatch")
                exit(1)
            }
            print("SELFTEST edit round-trip ok")
            // CLI validate of emitted YAML (binary presence gates this step)
            if Ch57xTool.binaryURL() != nil {
                try Ch57xTool().validate(emitted)
                try Ch57xTool().validate(editedYAML)
                print("SELFTEST cli validate ok")
            } else {
                print("SELFTEST WARN: CLI binary not found, skipped validate")
            }
            // M3: live-match normalization
            let norm: [(String, String)] = [
                ("ctrl-shift-w", "w"), ("{delay(100)}cmd-c", "c"), ("a,b,c", "a"),
                ("click(left+right)", "click(left+right)"), ("volumeup", "volumeup"),
                ("cmd-v", "v"), ("wheelup", "wheelup"),
            ]
            for (input, want) in norm {
                let got = MappingStore.normalizeAction(input)
                if got != want {
                    print("SELFTEST FAIL normalize '\(input)' → '\(got)' (want '\(want)')")
                    exit(2)
                }
            }
            print("SELFTEST normalize ok (\(norm.count) cases)")
            let clicks: [(String, UInt32?)] = [
                ("click", 1), ("click(left)", 1), ("click(middle)", 2),
                ("click(right)", 3), ("a", nil), ("wheelup", nil), ("click(both)", nil),
            ]
            for (a, want) in clicks {
                let got = MappingStore.mouseButton(for: a)
                if got != want {
                    print("SELFTEST FAIL mouseButton '\(a)' → \(String(describing: got)) (want \(String(describing: want)))")
                    exit(2)
                }
            }
            print("SELFTEST mouseButton ok (\(clicks.count) cases)")
            // M4/M5: config library + import paths against a temp dir.
            let libDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("mps-selftest-\(UUID().uuidString)")
            let lib = ConfigLibrary(dir: libDir)
            let saved1 = try lib.save(parsed, as: "My Config")
            if saved1 != "My Config" { print("SELFTEST FAIL library save name \(saved1)"); exit(2) }
            let saved2 = try lib.save(parsed, as: "My Config")   // collision
            if saved2 != "My Config (2)" { print("SELFTEST FAIL library collision name \(saved2)"); exit(2) }
            if lib.list().count != 2 { print("SELFTEST FAIL library list count"); exit(2) }
            let reloaded = try lib.load(saved1)
            if MappingYAML.emit(reloaded) != MappingYAML.emit(parsed) {
                print("SELFTEST FAIL library load round-trip"); exit(2)
            }
            let dup = try lib.duplicate("My Config")
            if !dup.contains("copy") || !lib.exists(dup) { print("SELFTEST FAIL library duplicate \(dup)"); exit(2) }
            let renamed = try lib.rename(dup, to: "Renamed Config")
            if lib.exists(dup) || !lib.exists(renamed) { print("SELFTEST FAIL library rename"); exit(2) }
            try lib.delete(renamed)
            if lib.exists(renamed) { print("SELFTEST FAIL library delete"); exit(2) }
            do {
                _ = try lib.importText("not: [valid: yaml: at: all", as: "bad")
                print("SELFTEST FAIL library importText accepted invalid YAML"); exit(2)
            } catch { /* expected */ }
            let imp = try lib.importText(MappingYAML.emit(parsed), as: "imported/../evil")
            if imp.contains("/") || !lib.exists(imp) { print("SELFTEST FAIL import sanitize \(imp)"); exit(2) }
            try? FileManager.default.removeItem(at: libDir)
            print("SELFTEST config library ok (save/collision/load/dup/rename/delete/import)")
            print("SELFTEST PASS")
            exit(0)
        } catch {
            print("SELFTEST FAIL: \(error.localizedDescription)")
            exit(1)
        }
    }

    /// Headless layout-overflow check: host the real ContentView in an offscreen
    /// NSHostingView at the minimum window size (980×540), force layout, then walk
    /// the NSView tree for any view whose frame spills outside the host bounds.
    /// `--select-key` pre-selects a pad key, reproducing the "inspector opens and
    /// the pad grid gets pushed off-screen" bug.
    static func runLayoutTest(args: [String]) -> Never {
        _ = NSApplication.shared
        let w: CGFloat = 980, h: CGFloat = 540
        let host = NSHostingView(rootView: ContentView().frame(width: w, height: h, alignment: .topLeading))
        host.frame = NSRect(x: 0, y: 0, width: w, height: h)
        host.layoutSubtreeIfNeeded()
        host.layoutSubtreeIfNeeded()   // second pass resolves min/ideal constraints

        var overflowCount = 0
        var widestBad: (name: String, rect: NSRect)?
        func walk(_ v: NSView) {
            let r = v.convert(v.bounds, to: host)
            if !r.isNull, r.width > 1, r.height > 1,
               r.minX < -1 || r.maxX > w + 1 || r.minY < -1 || r.maxY > h + 1 {
                overflowCount += 1
                if widestBad == nil || r.width > widestBad!.rect.width {
                    widestBad = (String(describing: type(of: v)), r)
                }
            }
            for s in v.subviews { walk(s) }
        }
        walk(host)

        let sel = args.contains("--select-key")
        if let bad = widestBad {
            print("LAYOUT FAIL selection=\(sel): \(overflowCount) view(s) out of bounds; widest: \(bad.name) x=\(bad.rect.minX) maxX=\(bad.rect.maxX) y=\(bad.rect.minY) maxY=\(bad.rect.maxY)")
            exit(1)
        }
        print("LAYOUT OK selection=\(sel): all views within \(Int(w))x\(Int(h))")
        exit(0)
    }
}
