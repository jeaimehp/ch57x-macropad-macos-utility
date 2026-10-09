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
