import Foundation

/// One physical control on one layer, with everything the guide needs to show it.
struct PadControl: Identifiable {
    enum Kind: Equatable { case button(row: Int, col: Int), knob(part: String) }
    let id: String          // note key
    let number: Int         // 1-based badge shared by the diagram and the listing
    let kind: Kind
    let position: String    // "Top row, left"
    let action: String
    let label: String       // note label, or plain-English fallback
    let detail: String      // note detail, or plain-English fallback
    let documented: Bool    // true when the config carries a # @note for it
    var keys: String { ActionDescriber.keys(action) }
}

enum PadControls {
    /// Buttons row-major, then knob CCW / press / CW — the order the badges count in.
    static func list(_ m: PadMapping, layer: Int = 0) -> [PadControl] {
        guard layer < m.layers.count else { return [] }
        let l = m.layers[layer]
        var out: [PadControl] = []
        for (r, row) in l.buttons.enumerated() {
            for (c, action) in row.enumerated() {
                let key = PadMapping.noteKey(layer: layer, button: r, col: c)
                out.append(make(m, key: key, number: out.count + 1, kind: .button(row: r, col: c),
                                position: buttonPosition(row: r, col: c, rows: l.buttons.count, cols: row.count),
                                action: action))
            }
        }
        if let k = l.knobs.first {
            for (part, action, pos) in [("ccw", k.ccw, "Knob — turn left (↺)"),
                                        ("press", k.press, "Knob — press"),
                                        ("cw", k.cw, "Knob — turn right (↻)")] {
                let key = PadMapping.noteKey(layer: layer, knob: part)
                out.append(make(m, key: key, number: out.count + 1, kind: .knob(part: part),
                                position: pos, action: action))
            }
        }
        return out
    }

    private static func make(_ m: PadMapping, key: String, number: Int, kind: PadControl.Kind,
                             position: String, action: String) -> PadControl {
        let note = m.notes[key]
        let label = (note?.label).flatMap { $0.isEmpty ? nil : $0 } ?? ActionDescriber.meaning(action)
        let detail = (note?.detail).flatMap { $0.isEmpty ? nil : $0 }
            ?? (note == nil ? "" : ActionDescriber.meaning(action))
        return PadControl(id: key, number: number, kind: kind, position: position, action: action,
                          label: label, detail: detail, documented: note != nil)
    }

    private static func buttonPosition(row: Int, col: Int, rows: Int, cols: Int) -> String {
        let r = rows == 2 ? (row == 0 ? "Top row" : "Bottom row") : "Row \(row + 1)"
        let c: String
        if cols == 3 { c = ["left", "middle", "right"][col] } else { c = "column \(col + 1)" }
        return "\(r), \(c)"
    }
}

/// Firmware limits the CLI's `validate` does not enforce: at most five accords per
/// sequence (upstream doc/actions.md), and no `{delay(...)}` options on this model
/// (the upload fails with "delay feature is not supported by this keyboard model").
enum MappingLint {
    static let maxAccords = 5

    /// Number of comma-separated accords, ignoring a leading `{options}` block and
    /// commas inside mouse-action parentheses like `move(10,0)`.
    static func accordCount(_ action: String) -> Int {
        var a = Substring(action.trimmingCharacters(in: .whitespaces))
        if a.hasPrefix("{"), let close = a.firstIndex(of: "}") { a = a[a.index(after: close)...] }
        guard !a.isEmpty else { return 0 }
        var depth = 0, count = 1
        for ch in a {
            if ch == "(" { depth += 1 } else if ch == ")" { depth = max(0, depth - 1) }
            else if ch == ",", depth == 0 { count += 1 }
        }
        return count
    }

    /// Human-readable problems, empty when the mapping fits the firmware.
    static func problems(_ m: PadMapping) -> [String] {
        var out: [String] = []
        for li in m.layers.indices {
            let prefix = m.layers.count > 1 ? "Layer \(li + 1), " : ""
            for c in PadControls.list(m, layer: li) {
                if c.action.trimmingCharacters(in: .whitespaces).hasPrefix("{") {
                    out.append("\(prefix)\(c.position): \"\(c.action)\" uses {options} like delay(), which this pad model doesn't support.")
                }
                let n = accordCount(c.action)
                if n > maxAccords {
                    out.append("\(prefix)\(c.position): \"\(c.action)\" is \(n) keystrokes — the pad plays at most \(maxAccords).")
                }
            }
        }
        return out
    }
}
