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
            // Notes: # @title/@summary/@note survive emit → parse, and the CLI ignores them.
            var noted = parsed
            noted.title = "Noted"; noted.summary = "Summary with | pipe"
            noted.notes = [PadMapping.noteKey(layer: 0, button: 0, col: 0): SlotNote(label: "Copy", detail: "Copies | text"),
                           PadMapping.noteKey(layer: 0, knob: "press"): SlotNote(label: "Mute")]
            noted.apps = ["f13": "com.meta.endo"]
            let notedYAML = MappingYAML.emit(noted)
            let notedBack = try MappingYAML.parse(notedYAML)
            guard notedBack == noted else { print("SELFTEST FAIL notes round-trip\n\(notedYAML)"); exit(2) }
            if Ch57xTool.binaryURL() != nil { try Ch57xTool().validate(notedYAML) }
            let ctl = PadControls.list(noted)
            guard ctl.count == parsed.rows * parsed.columns + (parsed.knobs > 0 ? 3 : 0),
                  ctl[0].label == "Copy", ctl[0].documented, !ctl[1].documented else {
                print("SELFTEST FAIL PadControls"); exit(2)
            }
            print("SELFTEST notes ok (round-trip, CLI-accepted, controls=\(ctl.count))")
            // Action descriptions shown in the template guide.
            let desc: [(String, String, String)] = [
                ("ctrl-c", "Ctrl + C", "Copy (Windows/Linux)"), ("numpadminus", "Numpad −", "Presses the Numpad − key"),
                ("<72>", "Pause (code 72)", "Sends the Pause key"), ("a", "A", "Types “A”"),
                ("volumeup", "Volume +", "Volume up"), ("g,s,t,enter", "gst⏎", "Types “gst⏎”"),
                ("ctrl-a,ctrl-c", "Ctrl + A → Ctrl + C", "Types the sequence Ctrl + A → Ctrl + C"), ("cmd-shift-4", "⌘ Cmd + Shift + 4", "Presses ⌘ Cmd + Shift + 4 together"),
            ]
            for (a, k, m) in desc {
                let gk = ActionDescriber.keys(a), gm = ActionDescriber.meaning(a)
                if gk != k || gm != m { print("SELFTEST FAIL describe '\(a)' → '\(gk)' / '\(gm)'"); exit(2) }
            }
            print("SELFTEST describe ok (\(desc.count) cases)")
            // Every bundled template parses, has docs, and passes CLI validate.
            let templates = TemplateLibrary.load()
            guard !templates.isEmpty else { print("SELFTEST FAIL no bundled templates"); exit(2) }
            for t in templates {
                guard t.mapping.title != nil, !t.mapping.notes.isEmpty else {
                    print("SELFTEST FAIL template '\(t.id)' missing @title/@note"); exit(2)
                }
                if Ch57xTool.binaryURL() != nil { try Ch57xTool().validate(MappingYAML.emit(t.mapping)) }
            }
            let accords: [(String, Int)] = [("a", 1), ("g,s,t,enter", 4), ("{delay(100)}left,a,right", 3),
                                            ("move(10,0)", 1), ("drag(left,10,0),a", 2), ("a,b,c,d,e,f", 6)]
            for (a, want) in accords where MappingLint.accordCount(a) != want {
                print("SELFTEST FAIL accordCount '\(a)' → \(MappingLint.accordCount(a)) (want \(want))"); exit(2)
            }
            var tooLong = parsed
            tooLong.layers[0].buttons[0][0] = "g,i,t,space,s,t,enter"
            guard MappingLint.problems(tooLong).count == 1, MappingLint.problems(parsed).isEmpty else {
                print("SELFTEST FAIL MappingLint.problems"); exit(2)
            }
            for t in templates where !MappingLint.problems(t.mapping).isEmpty {
                print("SELFTEST FAIL template '\(t.id)': \(MappingLint.problems(t.mapping))"); exit(2)
            }
            print("SELFTEST lint ok (≤\(MappingLint.maxAccords) keystrokes per sequence)")
            // Printable label sheet: every template renders to a 1-page Letter PDF.
            let pdfDir = FileManager.default.temporaryDirectory.appendingPathComponent("mps-pdf-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: pdfDir, withIntermediateDirectories: true)
            for t in templates {
              for style in [LabelSheetPDF.Style.stickers, .faceplate] {
                let url = pdfDir.appendingPathComponent("\(t.id)-\(style == .faceplate ? "faceplate" : "stickers").pdf")
                try MainActor.assumeIsolated { try LabelSheetPDF.write(mapping: t.mapping, title: t.name, style: style, to: url) }
                let data = try Data(contentsOf: url)
                guard data.count > 2000, data.prefix(4) == Data("%PDF".utf8),
                      let doc = CGPDFDocument(url as CFURL), doc.numberOfPages == 1,
                      doc.page(at: 1)?.getBoxRect(.mediaBox).size == LabelSheetView.page else {
                    print("SELFTEST FAIL label PDF for '\(t.id)' \(style)"); exit(2)
                }
              }
            }
            if ProcessInfo.processInfo.environment["MPS_KEEP_PDF"] != nil { print("SELFTEST pdfs kept in \(pdfDir.path)") }
            else { try? FileManager.default.removeItem(at: pdfDir) }
            print("SELFTEST label PDFs ok (\(templates.count) templates × stickers + faceplate, 1-page Letter)")
            print("SELFTEST templates ok (\(templates.map(\.name).joined(separator: ", ")))")
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
        let guide = args.contains("--guide")
        let w: CGFloat = guide ? 900 : 980, h: CGFloat = guide ? 620 : 540
        let root: AnyView = guide
            ? AnyView(TemplateGuideView(store: MappingStore()))
            : AnyView(ContentView().frame(width: w, height: h, alignment: .topLeading))
        let host = NSHostingView(rootView: root)
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
            print("LAYOUT FAIL selection=\(sel) guide=\(guide): \(overflowCount) view(s) out of bounds; widest: \(bad.name) x=\(bad.rect.minX) maxX=\(bad.rect.maxX) y=\(bad.rect.minY) maxY=\(bad.rect.maxY)")
            exit(1)
        }
        print("LAYOUT OK selection=\(sel) guide=\(guide): all views within \(Int(w))x\(Int(h))")
        exit(0)
    }
}
