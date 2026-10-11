import AppKit
import Carbon.HIToolbox

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
        guard let spec = specByID[id], let url = Self.appURL(spec) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config)   // launches or focuses
        onFire?(url.deletingPathExtension().lastPathComponent)
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
        appURL(spec)?.deletingPathExtension().lastPathComponent ?? spec
    }
}
