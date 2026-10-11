import Foundation

/// Named config library persisted as `.yaml` files (same format as ch57x-keyboard-tool).
/// Directory is injectable so selftests can run against a temp dir.
struct ConfigLibrary {
    let dir: URL

    /// `~/Library/Application Support/MicroPadStudio/configs`, shared by Studio and the
    /// menu helper. MICROPAD_SUPPORT_DIR (tests only) relocates the whole support dir.
    static func defaultDir() -> URL {
        if let override = ProcessInfo.processInfo.environment["MICROPAD_SUPPORT_DIR"] {
            return URL(fileURLWithPath: override).appendingPathComponent("configs", isDirectory: true)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MicroPadStudio/configs", isDirectory: true)
    }

    init(dir: URL = ConfigLibrary.defaultDir()) {
        self.dir = dir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    enum LibraryError: LocalizedError {
        case notFound(String)
        case invalid(String)
        var errorDescription: String? {
            switch self {
            case .notFound(let n): return "No config named '\(n)' in the library."
            case .invalid(let r):  return r
            }
        }
    }

    struct Entry: Identifiable, Hashable {
        let name: String
        let modified: Date?
        var id: String { name }
    }

    /// Sanitize a user-supplied name into a safe file base name.
    static func sanitize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " -_()."))
        var out = trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }.reduce(into: "") { $0.append($1) }
        out = out.trimmingCharacters(in: .whitespaces)
        return out.isEmpty ? "untitled" : out
    }

    private func url(for name: String) -> URL {
        dir.appendingPathComponent(name).appendingPathExtension("yaml")
    }

    /// All stored configs, newest first.
    func list() -> [Entry] {
        let fm = FileManager.default
        let files = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]))?
            .filter { $0.pathExtension == "yaml" } ?? []
        return files.map {
            let mods = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? nil
            return Entry(name: $0.deletingPathExtension().lastPathComponent, modified: mods)
        }
        .sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
    }

    func exists(_ name: String) -> Bool { FileManager.default.fileExists(atPath: url(for: name).path) }

    /// Returns the final name (may gain " (2)" etc. on collision).
    @discardableResult
    func save(_ mapping: PadMapping, as rawName: String) throws -> String {
        let base = Self.sanitize(rawName)
        var final = base, i = 2
        while exists(final) { final = "\(base) (\(i))"; i += 1 }
        let text = MappingYAML.emit(mapping)
        // Gate on the codec (CLI validate runs separately/asynchronously in the store).
        _ = try MappingYAML.parse(text)
        try text.write(to: url(for: final), atomically: true, encoding: .utf8)
        return final
    }

    /// Overwrite an existing entry in place (used by "Save").
    func overwrite(_ mapping: PadMapping, name: String) throws {
        guard exists(name) else { throw LibraryError.notFound(name) }
        let text = MappingYAML.emit(mapping)
        _ = try MappingYAML.parse(text)
        try text.write(to: url(for: name), atomically: true, encoding: .utf8)
    }

    func load(_ name: String) throws -> PadMapping {
        let path = url(for: name)
        guard let text = try? String(contentsOf: path, encoding: .utf8) else {
            throw LibraryError.notFound(name)
        }
        return try MappingYAML.parse(text)
    }

    /// Import raw YAML text under a chosen name; validates before writing.
    @discardableResult
    func importText(_ text: String, as rawName: String) throws -> String {
        let mapping = try MappingYAML.parse(text)   // throws with line-level errors
        return try save(mapping, as: rawName)
    }

    func duplicate(_ name: String) throws -> String {
        let mapping = try load(name)
        let base = Self.sanitize(name)
        var final = "\(base) copy", i = 2
        while exists(final) { final = "\(base) copy \(i)"; i += 1 }
        return try save(mapping, as: final)
    }

    func rename(_ old: String, to rawNew: String) throws -> String {
        let mapping = try load(old)
        let final = try save(mapping, as: rawNew)          // collision-safe
        if final != old { try delete(old) }
        return final
    }

    func delete(_ name: String) throws {
        let path = url(for: name)
        guard FileManager.default.fileExists(atPath: path.path) else { throw LibraryError.notFound(name) }
        try FileManager.default.removeItem(at: path)
    }
}
