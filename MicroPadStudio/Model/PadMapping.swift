import Foundation

/// Swift model of the ch57x-keyboard-tool YAML mapping format.
/// Format reference: https://github.com/kriomant/ch57x-keyboard-tool (example-mapping.yaml)
/// The serialized YAML is what the CLI consumes on stdin.

public struct PadMapping: Codable, Equatable {
    public var model: String
    public var orientation: Orientation
    public var rows: Int
    public var columns: Int
    public var knobs: Int
    public var layers: [PadLayer]
    /// Human documentation stored as `# @title / @summary / @note` YAML comments
    /// (ignored by the CLI). Notes are keyed by `PadMapping.noteKey(...)`.
    public var title: String?
    public var summary: String?
    public var notes: [String: SlotNote] = [:]
    /// `# @app <key> <bundle-id or app name>`: when this config is on the pad, the
    /// MicroPad Menu helper opens / focuses that app whenever the pad sends <key>
    /// (spare function keys f13–f20, which nothing else uses).
    public var apps: [String: String] = [:]

    public enum Orientation: String, Codable, CaseIterable, Identifiable {
        case normal, upsidedown, clockwise, counterclockwise
        public var id: String { rawValue }
        public var isVertical: Bool { self == .clockwise || self == .counterclockwise }
    }

    public init(model: String = "ch57x-2", orientation: Orientation = .normal,
                rows: Int, columns: Int, knobs: Int, layers: [PadLayer]) {
        self.model = model
        self.orientation = orientation
        self.rows = rows
        self.columns = columns
        self.knobs = knobs
        self.layers = layers
    }

    /// Stable note key for a control: "b<row>-<col>" (1-based) or "knob-ccw|press|cw",
    /// prefixed "L<n>." for layers after the first.
    public static func noteKey(layer: Int, button row: Int, col: Int) -> String {
        layerPrefix(layer) + "b\(row + 1)-\(col + 1)"
    }
    public static func noteKey(layer: Int, knob part: String) -> String {
        layerPrefix(layer) + "knob-\(part)"
    }
    private static func layerPrefix(_ layer: Int) -> String { layer == 0 ? "" : "L\(layer + 1)." }
}

/// What a control is *for*, e.g. label "Commander", detail "Selects your Commander…".
public struct SlotNote: Codable, Equatable {
    public var label: String
    public var detail: String
    public init(label: String, detail: String = "") {
        self.label = label
        self.detail = detail
    }
}

public struct PadLayer: Codable, Equatable {
    /// Button actions as [row][column] strings (ch57x action syntax).
    public var buttons: [[String]]
    /// Knob actions, one per knob (ordered left→right / top→bottom).
    public var knobs: [KnobActions]

    public init(buttons: [[String]], knobs: [KnobActions]) {
        self.buttons = buttons
        self.knobs = knobs
    }
}

public struct KnobActions: Codable, Equatable {
    public var ccw: String
    public var press: String
    public var cw: String

    public init(ccw: String, press: String, cw: String) {
        self.ccw = ccw
        self.press = press
        self.cw = cw
    }
}
