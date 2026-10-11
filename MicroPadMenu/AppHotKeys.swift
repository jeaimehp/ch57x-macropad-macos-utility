import AppKit
import Carbon.HIToolbox
import ApplicationServices

/// Global hotkeys for the spare function keys F13–F20. When the config on the pad
/// declares `# @app f13 com.meta.endo`, pressing that pad key makes the helper open
/// the app — or bring it forward if it's already running. Carbon hotkeys need no
/// Accessibility / Input Monitoring permission.
@MainActor
final class AppHotKeys {
    static let keyCodes: [String: Int] = [
        "f13": kVK_F13, "f14": kVK_F14, "f15": kVK_F15, "f16": kVK_F16,
        "f17": kVK_F17, "f18": kVK_F18, "f19": kVK_F19, "f20": kVK_F20,
    ]

    private(set) var active: [String: String] = [:]     // key → app spec
    private var refs: [EventHotKeyRef] = []
    private var specByID: [UInt32: String] = [:]
    private var handler: EventHandlerRef?
    var onFire: ((String) -> Void)?                      // reports the app name opened

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            guard let userData else { return noErr }
            let me = Unmanaged<AppHotKeys>.fromOpaque(userData).takeUnretainedValue()
            let id = hk.id
            DispatchQueue.main.async { MainActor.assumeIsolated { me.fire(id) } }
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    /// Re-registers only when the requested set changes. Returns how many keys are live.
    @discardableResult
    func update(_ apps: [String: String]) -> Int {
        let wanted = apps.filter { Self.keyCodes[$0.key] != nil }
        guard wanted != active else { return refs.count }
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll(); specByID.removeAll()
        for (i, (key, app)) in wanted.sorted(by: { $0.key < $1.key }).enumerated() {
            let id = UInt32(i + 1)
            var ref: EventHotKeyRef?
            let hkID = EventHotKeyID(signature: OSType(0x4D50_4D4E), id: id)   // 'MPMN'
            if RegisterEventHotKey(UInt32(Self.keyCodes[key]!), 0, hkID, GetApplicationEventTarget(), 0, &ref) == noErr,
               let ref {
                refs.append(ref)
                specByID[id] = app
            }
        }
        active = wanted
        return refs.count
    }

    private func fire(_ id: UInt32) {
        guard let spec = specByID[id] else { return }
        let (app, actions) = Self.parse(spec)
        guard let url = Self.appURL(app) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config)   // launches or focuses
        onFire?(url.deletingPathExtension().lastPathComponent)
        if actions.contains("dictate") { startDictation(in: url) }
    }

    /// "+dictate": once `url`'s app is frontmost (waits through a cold launch, max 8 s),
    /// start macOS Dictation — via the app's Edit → Start Dictation… menu item, else the
    /// "Press Control Key Twice" shortcut. Both need Accessibility; prompts the first time.
    private func startDictation(in url: URL) {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(opts) else {
            onFire?("⚠️ allow MicroPad Menu in System Settings → Privacy & Security → Accessibility, then press Dictate again")
            return
        }
        Task { @MainActor in
            let deadline = Date().addingTimeInterval(8)
            while NSWorkspace.shared.frontmostApplication?.bundleURL?.standardizedFileURL != url.standardizedFileURL {
                if Date() > deadline { return }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            try? await Task.sleep(nanoseconds: 300_000_000)   // let its window take key focus
            let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
            // Prefer the app's own Edit → Start Dictation… (works whatever the Dictation
            // shortcut is set to); fall back to the "Press Control Key Twice" shortcut.
            if !Self.pressStartDictationMenuItem(pid: pid) { Self.doubleTapControl() }
        }
    }

    /// Finds "Start Dictation…" in the app's menu bar via Accessibility and presses it.
    static func pressStartDictationMenuItem(pid: pid_t) -> Bool {
        guard pid > 0 else { return false }
        let app = AXUIElementCreateApplication(pid)
        func children(_ e: AXUIElement) -> [AXUIElement] {
            var v: CFTypeRef?
            guard AXUIElementCopyAttributeValue(e, kAXChildrenAttribute as CFString, &v) == .success else { return [] }
            return v as? [AXUIElement] ?? []
        }
        func title(_ e: AXUIElement) -> String {
            var v: CFTypeRef?
            AXUIElementCopyAttributeValue(e, kAXTitleAttribute as CFString, &v)
            return v as? String ?? ""
        }
        var bar: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXMenuBarAttribute as CFString, &bar) == .success,
              let menuBar = bar else { return false }
        for top in children(menuBar as! AXUIElement) {          // Apple, App, Edit, …
            for menu in children(top) {
                for item in children(menu) where title(item).hasPrefix("Start Dictation") {
                    return AXUIElementPerformAction(item, kAXPressAction as CFString) == .success
                }
            }
        }
        return false
    }

    static func doubleTapControl() {
        let src = CGEventSource(stateID: .hidSystemState)
        for _ in 0..<2 {
            for down in [true, false] {
                guard let e = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_Control), keyDown: down) else { continue }
                e.type = .flagsChanged
                e.flags = down ? .maskControl : []
                e.post(tap: .cghidEventTap)
                usleep(down ? 40_000 : 90_000)
            }
        }
    }

    /// "com.meta.endo +dictate" → ("com.meta.endo", ["dictate"]).
    static func parse(_ spec: String) -> (app: String, actions: Set<String>) {
        let parts = spec.split(separator: " ").map(String.init)
        let actions = Set(parts.filter { $0.hasPrefix("+") }.map { String($0.dropFirst()).lowercased() })
        let app = parts.filter { !$0.hasPrefix("+") }.joined(separator: " ")
        return (app, actions)
    }

    /// Bundle id first, then "<name>.app" in the usual application folders.
    static func appURL(_ spec: String) -> URL? {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: spec) { return url }
        let fm = FileManager.default
        let dirs = ["/Applications", "/System/Applications", "\(NSHomeDirectory())/Applications"]
        for d in dirs {
            let url = URL(fileURLWithPath: d).appendingPathComponent("\(spec).app")
            if fm.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    static func displayName(_ spec: String) -> String {
        let (app, actions) = parse(spec)
        let name = appURL(app)?.deletingPathExtension().lastPathComponent ?? app
        return actions.contains("dictate") ? "\(name) + dictate" : name
    }
}
