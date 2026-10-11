import Foundation

/// What was last flashed to the pad, shared by MicroPad Studio and the MicroPad Menu
/// helper through a JSON file in Application Support (the pad itself has no read-back,
/// so this is our best knowledge of its contents).
struct PadState: Codable, Equatable {
    var name: String          // display name, e.g. "Zoom (macOS)"
    var source: String        // "template" | "library" | "editor"
    var flashedAt: Date
    var yamlDigest: String    // detects "same content" independent of the name

    static func fileURL() -> URL {
        ConfigLibrary.defaultDir().deletingLastPathComponent().appendingPathComponent("pad-state.json")
    }

    static func load() -> PadState? {
        guard let data = try? Data(contentsOf: fileURL()) else { return nil }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(PadState.self, from: data)
    }

    static func record(name: String, source: String, yaml: String) {
        let state = PadState(name: name, source: source, flashedAt: Date(), yamlDigest: digest(yaml))
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601; enc.outputFormatting = .prettyPrinted
        guard let data = try? enc.encode(state) else { return }
        try? FileManager.default.createDirectory(at: fileURL().deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: fileURL(), options: .atomic)
    }

    /// FNV-1a over the mapping YAML (comments/notes stripped) — enough to tell
    /// configs apart; not security relevant.
    static func digest(_ yaml: String) -> String {
        let body = yaml.split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
            .joined(separator: "\n")
        var h: UInt64 = 0xcbf29ce484222325
        for b in body.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
        return String(format: "%016llx", h)
    }
}
