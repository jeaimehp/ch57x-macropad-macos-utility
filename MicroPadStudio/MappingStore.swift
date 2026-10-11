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
    @Published private(set) var yamlText: String

    // MARK: Live test (M3)
    private let live = LiveEventMonitor()
    @Published var liveOn = false
    @Published var liveAccessGranted = false
    @Published var liveLog: [String] = []
    @Published private(set) var pressedKeyName: String?
    @Published private(set) var wheelDir: String?   // "cw" | "ccw"
    private var wheelClearGeneration = 0

    // MARK: Config library (M4)
    let library = ConfigLibrary()
    @Published var activeConfigName: String?          // nil = unsaved working copy
    @Published var libraryEntries: [ConfigLibrary.Entry] = []

    // MARK: Templates + notes
    let templates: [PadTemplate] = TemplateLibrary.load()

    init() {
        // Default: the 3x2+1knob layout this project ships with (mapping.yaml @ a2e39b6).
        mapping = Self.defaultMapping
        yamlText = MappingYAML.emit(Self.defaultMapping)
        device.start()
        wireLiveMonitor()
        refreshLibrary()
    }

    // MARK: Config library actions (M4)

    func refreshLibrary() { libraryEntries = library.list() }

    /// Save under a name (new entry; collision → " (2)"). Sets it active.
    func saveConfigAs(_ name: String) {
        do {
            activeConfigName = try library.save(mapping, as: name)
            refreshLibrary()
            lastResult = "💾 saved as '\(activeConfigName!)'"
        } catch { lastResult = "❌ save failed: \(error.localizedDescription)" }
    }

    /// Save over the active entry.
    func saveConfig() {
        guard let name = activeConfigName else { return }
        do {
            try library.overwrite(mapping, name: name)
            refreshLibrary()
            lastResult = "💾 saved '\(name)'"
        } catch { lastResult = "❌ save failed: \(error.localizedDescription)" }
    }

    func applyConfig(_ name: String) {
        do {
            mapping = try library.load(name)
            yamlText = MappingYAML.emit(mapping)
            activeConfigName = name
            currentLayer = 0; selection = nil
            lastResult = "📂 loaded '\(name)'"
        } catch { lastResult = "❌ load failed: \(error.localizedDescription)" }
    }

    /// Put a built-in template into the editor as an unsaved working copy.
    func loadTemplate(_ t: PadTemplate) {
        mapping = t.mapping
        activeConfigName = nil
        currentLayer = 0; selection = nil
        lastResult = "📋 loaded template '\(t.name)' (not saved, not uploaded)"
    }

    func saveTemplateToLibrary(_ t: PadTemplate) {
        do {
            let name = try library.save(t.mapping, as: t.name)
            refreshLibrary()
            lastResult = "💾 template saved to library as '\(name)'"
        } catch { lastResult = "❌ save failed: \(error.localizedDescription)" }
    }

    func newConfig() {
        mapping = Self.defaultMapping
        yamlText = MappingYAML.emit(mapping)
        activeConfigName = nil
        currentLayer = 0; selection = nil
        lastResult = "🆕 new config (not saved)"
    }

    func duplicateConfig(_ name: String) {
        do {
            _ = try library.duplicate(name)
            refreshLibrary()
            lastResult = "📑 duplicated '\(name)'"
        } catch { lastResult = "❌ duplicate failed: \(error.localizedDescription)" }
    }

    func renameConfig(_ name: String, to newName: String) {
        do {
            let final = try library.rename(name, to: newName)
            if activeConfigName == name { activeConfigName = final }
            refreshLibrary()
            lastResult = "✏️ renamed → '\(final)'"
        } catch { lastResult = "❌ rename failed: \(error.localizedDescription)" }
    }

    func deleteConfig(_ name: String) {
        do {
            try library.delete(name)
            if activeConfigName == name { activeConfigName = nil }
            refreshLibrary()
            lastResult = "🗑 deleted '\(name)'"
        } catch { lastResult = "❌ delete failed: \(error.localizedDescription)" }
    }

    // MARK: Import / export (M5)

    /// Import YAML text (file picker or drag&drop). Validates via the codec before applying;
    /// also stores a copy in the library under the file's base name.
    func importConfig(text: String, name rawName: String) {
        do {
            let m = try MappingYAML.parse(text)
            mapping = m
            yamlText = MappingYAML.emit(m)
            activeConfigName = try library.save(m, as: rawName)
            currentLayer = 0; selection = nil
            refreshLibrary()
            lastResult = "📥 imported '\(activeConfigName!)' from file (saved to library)"
        } catch { lastResult = "❌ import failed: \(error.localizedDescription)" }
    }

    func importConfig(from url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            lastResult = "❌ import failed: cannot read '\(url.lastPathComponent)' as text"
            return
        }
        importConfig(text: text, name: url.deletingPathExtension().lastPathComponent)
    }

    /// Export the current working mapping to a file (M5).
    func exportConfig(to url: URL) {
        do {
            try MappingYAML.emit(mapping).write(to: url, atomically: true, encoding: .utf8)
            lastResult = "📤 exported to '\(url.lastPathComponent)'"
        } catch { lastResult = "❌ export failed: \(error.localizedDescription)" }
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

    /// Single layer: this pad has no layer-switch button, so extra layers are unreachable.
    static let defaultMapping = PadMapping(
        rows: 2, columns: 3, knobs: 1,
        layers: [
            PadLayer(buttons: [["a", "s", "d"], ["z", "x", "c"]],
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

    private func noteKey(_ slot: Slot) -> String {
        switch slot {
        case .button(let r, let c): return PadMapping.noteKey(layer: currentLayer, button: r, col: c)
        case .knobCCW:   return PadMapping.noteKey(layer: currentLayer, knob: "ccw")
        case .knobPress: return PadMapping.noteKey(layer: currentLayer, knob: "press")
        case .knobCW:    return PadMapping.noteKey(layer: currentLayer, knob: "cw")
        }
    }

    func note(for slot: Slot) -> SlotNote? { mapping.notes[noteKey(slot)] }

    /// Empty label + detail removes the note.
    func setNote(label: String, detail: String, for slot: Slot) {
        let l = label.trimmingCharacters(in: .whitespaces)
        let d = detail.trimmingCharacters(in: .whitespaces)
        mapping.notes[noteKey(slot)] = (l.isEmpty && d.isEmpty) ? nil : SlotNote(label: l, detail: d)
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
        guard !isBusy else { return }
        if let problem = MappingLint.problems(mapping).first {
            lastResult = "❌ \(problem)"
            return
        }
        isBusy = true
        lastResult = "⏳ validating…"
        let yaml = yamlText
        Task.detached(priority: .userInitiated) {
            let result: Result<String, Error>
            do { try Ch57xTool().validate(yaml); result = .success("✅ Config is valid.") }
            catch { result = .failure(error) }
            await MainActor.run {
                self.isBusy = false
                switch result {
                case .success(let msg): self.lastResult = msg
                case .failure(let e):   self.lastResult = "❌ \(e.localizedDescription)"
                }
            }
        }
    }

    func upload() {
        guard !isBusy else { return }
        // Release our own IOHIDManager listen before the vendor write: a held
        // interface can stall the upload (documented tool pitfall).
        if let problem = MappingLint.problems(mapping).first {
            lastResult = "❌ not uploaded — \(problem)"
            return
        }
        if liveOn { setLive(on: false) }
        isBusy = true
        lastResult = "⏳ Uploading to pad — do not unplug…"
        let yaml = yamlText
        let padName = activeConfigName ?? mapping.title ?? "Editor (unsaved)"
        let padSource = activeConfigName != nil ? "library" : "editor"
        Task.detached(priority: .userInitiated) {
            let result: Result<String, Error>
            do {
                let tool = Ch57xTool()
                try tool.validate(yaml)   // never upload invalid config
                try tool.upload(yaml)
                PadState.record(name: padName, source: padSource, yaml: yaml)
                result = .success("✅ Uploaded to pad.")
            } catch { result = .failure(error) }
            await MainActor.run {
                self.isBusy = false
                switch result {
                case .success(let msg): self.lastResult = msg
                case .failure(let e):   self.lastResult = "❌ \(e.localizedDescription)"
                }
            }
        }
    }
}
