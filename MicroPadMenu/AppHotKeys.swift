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
        var specs = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                     EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            guard let event, let userData else { return noErr }
            let me = Unmanaged<AppHotKeys>.fromOpaque(userData).takeUnretainedValue()
            let id = hk.id
            let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
            DispatchQueue.main.async { MainActor.assumeIsolated { me.fire(id, pressed: pressed) } }
            return noErr
        }, 2, &specs, Unmanaged.passUnretained(self).toOpaque(), &handler)
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

    // MARK: - Diagnostics log (~/Library/Logs/MicroPad Menu.log)

    static let logURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Logs/MicroPad Menu.log")

    static func log(_ msg: String) {
        let line = "\(ISO8601DateFormatter.string(from: Date(), timeZone: .current, formatOptions: [.withInternetDateTime, .withFractionalSeconds])) \(msg)\n"
        if let h = try? FileHandle(forWritingTo: logURL) {
            h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close()
        } else {
            try? line.write(to: logURL, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Firing

    /// Hold-to-talk state for "+dictate" keys.
    private enum Dictation { case idle, starting, active }
    private var dictation = Dictation.idle
    private var pressedAt = Date.distantPast
    private var latched = false          // quick tap → keep dictating until the next tap
    private var stopWhenStarted = false  // released before dictation finished starting
    private var dictationPID: pid_t = 0
    static let tapThreshold: TimeInterval = 0.5

    private func fire(_ id: UInt32, pressed: Bool) {
        guard let spec = specByID[id] else { return }
        let key = active.first { $0.value == spec }?.key.uppercased() ?? "?"
        Self.log(pressed ? "\(key) pressed (state \(dictation))"
                         : "\(key) released after \(String(format: "%.3f", Date().timeIntervalSince(pressedAt)))s (state \(dictation))")
        let (app, actions) = Self.parse(spec)
        guard let url = Self.appURL(app) else { return }
        if actions.contains("dictate") {
            pressed ? dictatePressed(url) : dictateReleased()
            return
        }
        guard pressed else { return }
        activate(url)
    }

    private func activate(_ url: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config)   // launches or focuses
        onFire?(url.deletingPathExtension().lastPathComponent)
    }

    /// Press: a latched (tap-started) dictation stops; otherwise focus the app and start.
    private func dictatePressed(_ url: URL) {
        if dictation == .active && latched { stopDictation(); return }
        guard dictation == .idle else { return }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(opts) else {
            onFire?("⚠️ allow MicroPad Menu in System Settings → Privacy & Security → Accessibility, then press Dictate again")
            return
        }
        pressedAt = Date(); latched = false; stopWhenStarted = false
        dictation = .starting
        activate(url)
        Task { @MainActor in
            // Wait for the app to be frontmost (covers a cold launch), max 8 s.
            let deadline = Date().addingTimeInterval(8)
            while NSWorkspace.shared.frontmostApplication?.bundleURL?.standardizedFileURL != url.standardizedFileURL {
                if Date() > deadline { self.dictation = .idle; return }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            try? await Task.sleep(nanoseconds: 300_000_000)   // let its window take key focus
            self.dictationPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
            // Prefer the app's own Edit → Start Dictation… (works whatever the Dictation
            // shortcut is); fall back to the "Press Control Key Twice" shortcut.
            let viaMenu = Self.pressMenuItem(prefix: "Start Dictation", pid: self.dictationPID)
            if !viaMenu { Self.doubleTapControl() }
            Self.log("dictation started via \(viaMenu ? "Edit menu" : "Control×2")")
            self.dictation = .active
            if self.stopWhenStarted { self.stopDictation() }
        }
    }

    /// Release: a quick tap latches dictation on; a hold stops it (push-to-talk).
    private func dictateReleased() {
        let held = Date().timeIntervalSince(pressedAt)
        switch dictation {
        case .idle:
            return
        case .starting:
            if held < Self.tapThreshold { latched = true } else { stopWhenStarted = true }
        case .active:
            if latched { return }                       // the stop happens on the next press
            if held < Self.tapThreshold { latched = true } else { stopDictation() }
        }
    }

    private func stopDictation() {
        let pid = dictationPID
        dictation = .idle; latched = false; stopWhenStarted = false
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)   // let the last words land
            _ = pid
            // Esc ends macOS Dictation and keeps the text (confirmed on this Mac; the
            // menu item/Control×2 toggles did not stop it).
            Self.tapKey(CGKeyCode(kVK_Escape))
            Self.log("dictation stopped via Esc")
        }
    }

    static func tapKey(_ code: CGKeyCode) {
        let src = CGEventSource(stateID: .hidSystemState)
        CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)?.post(tap: .cghidEventTap)
        usleep(20_000)
        CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)?.post(tap: .cghidEventTap)
    }

    /// Finds a menu item whose title starts with `prefix` (e.g. "Start Dictation") in the
    /// app's menu bar via Accessibility and presses it.
    static func pressMenuItem(prefix: String, pid: pid_t) -> Bool {
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
                for item in children(menu) where title(item).hasPrefix(prefix) {
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
