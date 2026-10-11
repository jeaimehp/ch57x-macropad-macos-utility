import AppKit
import Combine
import ServiceManagement

/// State + actions for the MicroPad Menu helper: lists built-in templates and saved
/// library configs, flashes one to the pad, and tracks what the pad currently holds.
@MainActor
final class MenuModel: ObservableObject {
    struct Item: Identifiable {
        let id: String          // "template:<id>" | "library:<name>"
        let name: String
        let source: String      // "template" | "library"
        let mapping: PadMapping
        var digest: String { PadState.digest(MappingYAML.emit(mapping)) }
    }

    let device = DeviceMonitor()
    @Published private(set) var templates: [Item] = []
    @Published private(set) var saved: [Item] = []
    @Published private(set) var padState: PadState?
    @Published private(set) var flashing: String?          // name being flashed
    @Published private(set) var lastMessage: String?
    @Published var askBeforeFlashing: Bool {
        didSet { UserDefaults.standard.set(askBeforeFlashing, forKey: Self.askKey) }
    }

    private static let askKey = "askBeforeFlashing"
    private let library = ConfigLibrary()
    private var refreshTimer: Timer?
    private var deviceSink: AnyCancellable?

    init() {
        askBeforeFlashing = UserDefaults.standard.object(forKey: Self.askKey) as? Bool ?? true
        templates = TemplateLibrary.load().map {
            Item(id: "template:\($0.id)", name: $0.name, source: "template", mapping: $0.mapping)
        }
        device.start()
        // Re-publish device changes so the menu bar icon updates.
        deviceSink = device.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        refresh()
        // Library and pad state can change from MicroPad Studio; poll cheaply.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        saved = library.list().compactMap { e in
            (try? library.load(e.name)).map {
                Item(id: "library:\(e.name)", name: e.name, source: "library", mapping: $0)
            }
        }
        padState = PadState.load()
    }

    /// True when this item's buttons/knob match what was last flashed (notes ignored).
    func isOnPad(_ item: Item) -> Bool { padState?.yamlDigest == item.digest }

    // MARK: - Flashing

    func requestFlash(_ item: Item) {
        guard flashing == nil else { return }
        if let problem = MappingLint.problems(item.mapping).first {
            lastMessage = "❌ \(problem)"
            return
        }
        guard device.connected else {
            lastMessage = "❌ Pad not connected — plug it in via USB."
            return
        }
        if askBeforeFlashing && !confirm(item) { return }
        flash(item)
    }

    private func confirm(_ item: Item) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Flash “\(item.name)” to the pad?"
        alert.informativeText = "This replaces the mapping stored on the pad (it can't be read back). Takes about a minute — don't unplug the pad."
        alert.addButton(withTitle: "Flash")
        alert.addButton(withTitle: "Cancel")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don't ask again"
        let ok = alert.runModal() == .alertFirstButtonReturn
        if ok && alert.suppressionButton?.state == .on { askBeforeFlashing = false }
        return ok
    }

    func flash(_ item: Item) {
        flashing = item.name
        lastMessage = nil
        let yaml = MappingYAML.emit(item.mapping)
        let name = item.name, source = item.source
        Task.detached(priority: .userInitiated) {
            let result: Result<Void, Error>
            do {
                let tool = Ch57xTool()
                try tool.validate(yaml)
                try tool.upload(yaml)
                PadState.record(name: name, source: source, yaml: yaml)
                result = .success(())
            } catch { result = .failure(error) }
            await MainActor.run {
                self.flashing = nil
                self.refresh()
                switch result {
                case .success:
                    self.lastMessage = "✅ “\(name)” is on the pad."
                    NSSound(named: "Glass")?.play()
                case .failure(let e):
                    self.lastMessage = "❌ \(e.localizedDescription)"
                    NSSound(named: "Basso")?.play()
                }
            }
        }
    }

    // MARK: - App actions

    func openStudio() {
        let ws = NSWorkspace.shared
        let sibling = Bundle.main.bundleURL.deletingLastPathComponent()
            .appendingPathComponent("MicroPadStudio.app")
        let url = ws.urlForApplication(withBundleIdentifier: "com.micropadstudio.app")
            ?? (FileManager.default.fileExists(atPath: sibling.path) ? sibling : nil)
        guard let url else { lastMessage = "❌ MicroPad Studio not found."; return }
        ws.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch { lastMessage = "❌ Launch at login: \(error.localizedDescription)" }
            objectWillChange.send()
        }
    }
}
