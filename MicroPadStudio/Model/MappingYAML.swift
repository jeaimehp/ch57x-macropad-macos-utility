import Foundation
import Yams

/// Errors with human-readable messages suitable for direct UI display.
enum MappingCodecError: LocalizedError {
    case notADictionary
    case missingKey(String, context: String)
    case badType(String, context: String, found: String)
    case emptyLayers

    var errorDescription: String? {
        switch self {
        case .notADictionary:
            return "Top level of the config must be a mapping (key: value)."
        case .missingKey(let key, let ctx):
            return "Missing required key \"\(key)\" \(ctx)."
        case .badType(let key, let ctx, let found):
            return "Key \"\(key)\" \(ctx) has wrong type (found \(found))."
        case .emptyLayers:
            return "Config must contain at least one layer."
        }
    }
}

enum MappingYAML {

    // MARK: - Emit (deterministic, upstream-compatible format)

    public static func emit(_ m: PadMapping) -> String {
        var out = emitDocs(m)
        out += "model: \(yamlString(m.model))\n"
        out += "orientation: \(m.orientation.rawValue)\n"
        out += "rows: \(m.rows)\n"
        out += "columns: \(m.columns)\n"
        out += "knobs: \(m.knobs)\n"
        out += "layers:\n"
        for layer in m.layers {
            out += "  - buttons:\n"
            for row in layer.buttons {
                let cells = row.map { yamlString($0) }.joined(separator: ", ")
                out += "      - [\(cells)]\n"
            }
            out += "    knobs:\n"
            for k in layer.knobs {
                out += "      - ccw: \(yamlString(k.ccw))\n"
                out += "        press: \(yamlString(k.press))\n"
                out += "        cw: \(yamlString(k.cw))\n"
            }
        }
        return out
    }

    /// `# @…` comment header carrying title/summary/notes. Notes are emitted in
    /// key order so output stays deterministic.
    private static func emitDocs(_ m: PadMapping) -> String {
        var out = ""
        if let t = m.title, !t.isEmpty { out += "# @title \(oneLine(t))\n" }
        if let s = m.summary, !s.isEmpty { out += "# @summary \(oneLine(s))\n" }
        for key in m.notes.keys.sorted() {
            let n = m.notes[key]!
            let label = oneLine(n.label).replacingOccurrences(of: "|", with: "/")
            out += "# @note \(key) \(label)"
            if !n.detail.isEmpty { out += " | \(oneLine(n.detail))" }
            out += "\n"
        }
        if !out.isEmpty { out += "\n" }
        return out
    }

    private static func oneLine(_ s: String) -> String {
        s.components(separatedBy: .newlines).joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Reads `# @title`, `# @summary`, `# @note <key> <label> [| <detail>]` lines.
    static func parseDocs(_ text: String) -> (title: String?, summary: String?, notes: [String: SlotNote]) {
        var title: String?, summary: String?
        var notes: [String: SlotNote] = [:]
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("#") else { continue }
            let body = line.dropFirst().trimmingCharacters(in: .whitespaces)
            guard body.hasPrefix("@") else { continue }
            let parts = body.dropFirst().split(separator: " ", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            switch parts[0] {
            case "title": title = value
            case "summary": summary = value
            case "note":
                let kv = value.split(separator: " ", maxSplits: 1).map(String.init)
                guard kv.count == 2 else { continue }
                let pieces = kv[1].split(separator: "|", maxSplits: 1).map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
                notes[kv[0]] = SlotNote(label: pieces[0], detail: pieces.count > 1 ? pieces[1] : "")
            default: continue
            }
        }
        return (title, summary, notes)
    }

    private static func yamlString(_ s: String) -> String {
        // Double-quote everything; escape backslash and quote. Safe superset.
        let escaped = s.replacingOccurrences(of: "\\", with: "\\\\")
                       .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    // MARK: - Parse (accepts arbitrary YAML incl. comments & flow style)

    public static func parse(_ text: String) throws -> PadMapping {
        guard let top = try Yams.load(yaml: text) else { throw MappingCodecError.notADictionary }
        guard let dict = top as? [String: Any] else { throw MappingCodecError.notADictionary }

        guard let model = dict["model"] as? String else {
            throw MappingCodecError.missingKey("model", context: "at top level")
        }
        let orientationRaw = dict["orientation"] as? String ?? "normal"
        guard let orientation = PadMapping.Orientation(rawValue: orientationRaw) else {
            throw MappingCodecError.badType("orientation", context: "at top level",
                                            found: "\"\(orientationRaw)\" (valid: \(PadMapping.Orientation.allCases.map(\.rawValue).joined(separator: ", ")))")
        }
        guard let rows = dict["rows"] as? Int else {
            throw MappingCodecError.missingKey("rows", context: "at top level")
        }
        guard let columns = dict["columns"] as? Int else {
            throw MappingCodecError.missingKey("columns", context: "at top level")
        }
        let knobs = dict["knobs"] as? Int ?? 0

        guard let rawLayers = dict["layers"] as? [[String: Any]], !rawLayers.isEmpty else {
            throw MappingCodecError.emptyLayers
        }

        var layers: [PadLayer] = []
        for (li, l) in rawLayers.enumerated() {
            guard let rawButtons = l["buttons"] as? [[Any]] else {
                throw MappingCodecError.missingKey("buttons", context: "in layer \(li + 1)")
            }
            var buttons: [[String]] = []
            for (ri, row) in rawButtons.enumerated() {
                guard row.allSatisfy({ $0 is String }) else {
                    throw MappingCodecError.badType("buttons[\(ri)]", context: "in layer \(li + 1)", found: "non-string entry")
                }
                buttons.append(row as! [String])
            }
            var knobList: [KnobActions] = []
            if let rawKnobs = l["knobs"] as? [[String: Any]] {
                for (ki, k) in rawKnobs.enumerated() {
                    guard let ccw = k["ccw"] as? String,
                          let press = k["press"] as? String,
                          let cw = k["cw"] as? String else {
                        throw MappingCodecError.missingKey("ccw/press/cw",
                            context: "in knob \(ki + 1) of layer \(li + 1)")
                    }
                    knobList.append(KnobActions(ccw: ccw, press: press, cw: cw))
                }
            }
            layers.append(PadLayer(buttons: buttons, knobs: knobList))
        }

        var mapping = PadMapping(model: model, orientation: orientation,
                                 rows: rows, columns: columns, knobs: knobs, layers: layers)
        (mapping.title, mapping.summary, mapping.notes) = parseDocs(text)
        return mapping
    }
}
