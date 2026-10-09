import Foundation
import Combine

/// Single source of truth for the currently-edited mapping + device actions.
@MainActor
final class MappingStore: ObservableObject {
    @Published var mapping: PadMapping { didSet { markDirty() } }
    @Published var lastResult: String?
    @Published var isBusy = false

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
