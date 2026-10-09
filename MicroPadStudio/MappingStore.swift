import Foundation
import Combine

/// Single source of truth for the currently-edited mapping + device actions.
@MainActor
final class MappingStore: ObservableObject {
    @Published var mapping: PadMapping { didSet { markDirty() } }
    @Published var lastResult: String?
    @Published var isBusy = false

    // MARK: Editor state (M2)
    /// A selectable control on the pad.
    enum Slot: Hashable {
        case button(row: Int, col: Int)
        case knobCCW, knobPress, knobCW
    }
    @Published var currentLayer = 0 { didSet { if currentLayer >= mapping.layers.count { currentLayer = 0 } } }
    @Published var selection: Slot?

    let device = DeviceMonitor()
    private let tool = Ch57xTool()
    @Published private(set) var yamlText: String

    init() {
        // Default: the 3x2+1knob layout this project ships with (mapping.yaml @ a2e39b6).
        mapping = Self.defaultMapping
        yamlText = MappingYAML.emit(Self.defaultMapping)
        device.start()
    }

    static let defaultMapping = PadMapping(
        rows: 2, columns: 3, knobs: 1,
        layers: [
            PadLayer(buttons: [["a", "s", "d"], ["z", "x", "c"]],
                     knobs: [KnobActions(ccw: "wheelup", press: "click", cw: "wheeldown")]),
            PadLayer(buttons: [["1", "2", "3"], ["4", "5", "6"]],
                     knobs: [KnobActions(ccw: "volumedown", press: "mute", cw: "volumeup")]),
            PadLayer(buttons: [["play", "prev", "next"], ["enter", "escape", "space"]],
                     knobs: [KnobActions(ccw: "left", press: "enter", cw: "right")]),
        ])

    private func markDirty() { yamlText = MappingYAML.emit(mapping) }

    // MARK: Slot access (M2)

    /// Current action string bound to `slot` on the currently edited layer.
    func action(for slot: Slot) -> String {
        guard currentLayer < mapping.layers.count else { return "" }
        let layer = mapping.layers[currentLayer]
        switch slot {
        case .button(let r, let c):
            guard r < layer.buttons.count, c < layer.buttons[r].count else { return "" }
            return layer.buttons[r][c]
        case .knobCCW:  return layer.knobs.first?.ccw ?? ""
        case .knobPress: return layer.knobs.first?.press ?? ""
        case .knobCW:   return layer.knobs.first?.cw ?? ""
        }
    }

    /// Write `action` into `slot` on the currently edited layer (triggers YAML re-emit).
    func assign(_ action: String, to slot: Slot) {
        guard currentLayer < mapping.layers.count else { return }
        var layer = mapping.layers[currentLayer]
        switch slot {
        case .button(let r, let c):
            guard r < layer.buttons.count, c < layer.buttons[r].count else { return }
            layer.buttons[r][c] = action
        case .knobCCW, .knobPress, .knobCW:
            guard !layer.knobs.isEmpty else { return }
            switch slot {
            case .knobCCW:  layer.knobs[0].ccw = action
            case .knobPress: layer.knobs[0].press = action
            case .knobCW:   layer.knobs[0].cw = action
            case .button: break
            }
        }
        mapping.layers[currentLayer] = layer
    }

    func slotLabel(_ slot: Slot) -> String {
        switch slot {
        case .button(let r, let c): return "Button \(r + 1)·\(c + 1) (row \(r + 1), col \(c + 1))"
        case .knobCCW: return "Knob — rotate counter-clockwise"
        case .knobPress: return "Knob — press"
        case .knobCW: return "Knob — rotate clockwise"
        }
    }

    func validate() {
        isBusy = true; defer { isBusy = false }
        do {
            try tool.validate(yamlText)
            lastResult = "✅ Config is valid."
        } catch {
            lastResult = "❌ \(error.localizedDescription)"
        }
    }

    func upload() {
        isBusy = true; defer { isBusy = false }
        do {
            try tool.validate(yamlText)   // never upload invalid config
            try tool.upload(yamlText)
            lastResult = "✅ Uploaded to pad."
        } catch {
            lastResult = "❌ \(error.localizedDescription)"
        }
    }
}
