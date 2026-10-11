import Foundation

/// Built-in mapping templates shipped in the app bundle (`Resources/templates/*.yaml`,
/// copied from the repo's `templates/` folder). Read-only; users load one into the
/// editor and save it to their library to customise.
struct PadTemplate: Identifiable, Equatable {
    let id: String          // file base name
    let name: String
    let mapping: PadMapping
}

enum TemplateLibrary {
    static func directory() -> URL? {
        Bundle.main.resourceURL?.appendingPathComponent("templates", isDirectory: true)
    }

    /// All parseable templates, sorted by display name. Unparseable files are skipped
    /// (the selftest validates every bundled template, so this never hides a shipped bug).
    static func load(from dir: URL? = directory()) -> [PadTemplate] {
        guard let dir,
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        else { return [] }
        return files
            .filter { ["yaml", "yml"].contains($0.pathExtension.lowercased()) }
            .compactMap { url -> PadTemplate? in
                guard let text = try? String(contentsOf: url, encoding: .utf8),
                      let m = try? MappingYAML.parse(text) else { return nil }
                let base = url.deletingPathExtension().lastPathComponent
                return PadTemplate(id: base, name: m.title ?? base, mapping: m)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
