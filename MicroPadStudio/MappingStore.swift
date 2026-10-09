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

    // MARK: Live test (M3)
    private let live = LiveEventMonitor()
    @Published var liveOn = false
    @Published var liveAccessGranted = false
    @Published var liveLog: [String] = []
    @Published private(set) var pressedKeyName: String?
    @Published private(set) var wheelDir: String?   // "cw" | "ccw"
    private var wheelClearGeneration = 0

    init() {
        // Default: the 3x2+1knob layout this project ships with (mapping.yaml @ a2e39b6).
        mapping = Self.defaultMapping
        yamlText = MappingYAML.emit(Self.defaultMapping)
        device.start()
        wireLiveMonitor()
    }

    // MARK: Live test wiring (M3)

    private func wireLiveMonitor() {
        live.onKey = { [weak self] name, isDown in
            guard let self else { return }
            if isDown {
                self.pressedKeyName = name
                self.appendLiveLog("⬇︎ \(name)")
            } else if self.pressedKeyName == name {
                self.pressedKeyName = nil
            }
        }
        live.onWheel = { [weak self] delta in
            guard let self, delta != 0 else { return }
            self.wheelDir = delta > 0 ? "cw" : "ccw"
            self.appendLiveLog("↻ knob \(delta > 0 ? "cw" : "ccw") (\(delta))")
            self.wheelClearGeneration += 1
            let gen = self.wheelClearGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                if self?.wheelClearGeneration == gen { self?.wheelDir = nil }
            }
        }
        live.onMouseButton = { [weak self] button, isDown in
            guard let self else { return }
            if isDown {
                self.pressedKeyName = "_mouse\(button)"
                self.appendLiveLog("🖰 mouse button \(button) down")
            } else if self.pressedKeyName == "_mouse\(button)" {
                self.pressedKeyName = nil
            }
        }
    }

    private func appendLiveLog(_ line: String) {
        let stamp = Self.liveTimeFormatter.string(from: Date())
        liveLog.insert("\(stamp)  \(line)", at: 0)
        if liveLog.count > 40 { liveLog.removeLast(liveLog.count - 40) }
    }

    private static let liveTimeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f
    }()

    func setLive(on: Bool) {
        liveOn = on
        if on {
            liveAccessGranted = live.start()
            appendLiveLog(liveAccessGranted
                ? "monitor started (pad \(device.connected ? "connected" : "NOT detected"))"
                : "⚠︎ no Input Monitoring permission — allow it in System Settings → Privacy & Security → Input Monitoring, then re-toggle")
        } else {
            live.stop()
            pressedKeyName = nil; wheelDir = nil
            appendLiveLog("monitor stopped")
        }
    }

    /// Reduce an action string to its base key/token for live-match highlighting.
    /// "ctrl-shift-w" → "w", "click(left+right)" → itself, "{delay(100)}cmd-c" → "c",
    /// "a,b,c" sequence → "a" (the first event the pad emits).
    nonisolated static func normalizeAction(_ a: String) -> String {
        var s = a.trimmingCharacters(in: .whitespaces)
        while s.hasPrefix("{"), let i = s.firstIndex(of: "}") {
            s = String(s[s.index(after: i)...]).trimmingCharacters(in: .whitespaces)
        }
        if let first = s.split(separator: ",").first { s = String(first).trimmingCharacters(in: .whitespaces) }
        let mods: Set<String> = ["ctrl", "shift", "alt", "opt", "win", "cmd",
                                 "rctrl", "rshift", "ralt", "ropt", "rwin", "rcmd"]
        var parts = s.split(separator: "-", omittingEmptySubsequences: false).map { $0.lowercased() }
        while parts.count > 1, mods.contains(parts[0]) { parts.removeFirst() }
        s = parts.joined(separator: "-")
        return s
    }

    /// Mouse button number an action string emits, if it is a click action.
    /// "click" → 1, "click(middle)" → 2, "click(right)" → 3, "click(left)" → 1.
    nonisolated static func mouseButton(for action: String) -> UInt32? {
        let a = normalizeAction(action)
        guard a == "click" || (a.hasPrefix("click(") && a.hasSuffix(")")) else { return nil }
        switch a.dropFirst(6).dropLast(1).trimmingCharacters(in: .whitespaces) {
        case "", "left": return 1
        case "middle":   return 2
        case "right":    return 3
        default:         return nil
        }
    }

    /// True when a live event should light up `slot` (M3 highlighting).
    func isSlotPressed(_ slot: Slot) -> Bool {
        guard liveOn else { return false }
        switch slot {
        case .knobCW:  return wheelDir == "cw"
        case .knobCCW: return wheelDir == "ccw"
        default:
            guard let pressed = pressedKeyName else { return false }
            if pressed.hasPrefix("_mouse") {
                let btn = UInt32(pressed.dropFirst(6)) ?? 0
                return Self.mouseButton(for: action(for: slot)) == btn
            }
            return Self.normalizeAction(action(for: slot)) == pressed
        }
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
