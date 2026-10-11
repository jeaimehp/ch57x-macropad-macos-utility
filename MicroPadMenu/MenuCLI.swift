import Foundation

/// `MicroPad Menu --flash <template id | template name | saved config name>`:
/// scriptable flash using the same validate → upload → PadState path as the menu.
enum MenuCLI {
    static func flash(_ query: String) -> Never {
        let templates = TemplateLibrary.load()
        let library = ConfigLibrary()
        let q = query.lowercased()
        var found: (name: String, source: String, mapping: PadMapping)?
        if let t = templates.first(where: { $0.id.lowercased() == q || $0.name.lowercased() == q }) {
            found = (t.name, "template", t.mapping)
        } else if let e = library.list().first(where: { $0.name.lowercased() == q }),
                  let m = try? library.load(e.name) {
            found = (e.name, "library", m)
        }
        guard let (name, source, mapping) = found else {
            print("FLASH FAIL: no template or saved config named '\(query)'")
            print("templates: " + templates.map(\.id).joined(separator: ", "))
            exit(2)
        }
        if let problem = MappingLint.problems(mapping).first { print("FLASH FAIL: \(problem)"); exit(1) }
        let yaml = MappingYAML.emit(mapping)
        print("FLASH validating + uploading '\(name)' (about a minute — don't unplug the pad)…")
        do {
            let tool = Ch57xTool()
            try tool.validate(yaml)
            try tool.upload(yaml)
            PadState.record(name: name, source: source, yaml: yaml)
            print("FLASH OK: '\(name)' is on the pad")
            exit(0)
        } catch {
            print("FLASH FAIL: \(error.localizedDescription)")
            exit(1)
        }
    }
}
