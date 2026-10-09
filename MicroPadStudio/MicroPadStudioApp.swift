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
            print("SELFTEST PASS")
            exit(0)
        } catch {
            print("SELFTEST FAIL: \(error.localizedDescription)")
            exit(1)
        }
    }
}
