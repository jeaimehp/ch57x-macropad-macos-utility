import Foundation

/// Turns raw ch57x action strings into human text for the template guide:
/// `keys` is how the keystroke reads ("Ctrl + C"), `meaning` is a fallback
/// explanation used when a config carries no `# @note` for that control.
enum ActionDescriber {

    static func keys(_ action: String) -> String {
        let a = action.trimmingCharacters(in: .whitespaces)
        if a.isEmpty { return "—" }
        if a.contains(",") {                       // sequence of accords
            return a.split(separator: ",").map { keys(String($0)) }.joined(separator: " → ")
        }
        if let raw = rawCode(a) {
            return rawNames[raw].map { "\($0) (code \(raw))" } ?? "HID code \(raw)"
        }
        if a.hasPrefix("{") { return keys(String(a.drop { $0 != "}" }.dropFirst())) }
        if a.contains("(") { return mouseText(a) ?? a }
        return a.split(separator: "-").map { keyName(String($0)) }.joined(separator: " + ")
    }

    static func meaning(_ action: String) -> String {
        let a = action.trimmingCharacters(in: .whitespaces).lowercased()
        if let m = known[a] { return m }
        if let raw = rawCode(a), let name = rawNames[raw] { return "Sends the \(name) key" }
        if a.contains(",") { return "Types the sequence \(keys(a))" }
        if a.contains("(") { return mouseText(a) ?? "Custom mouse action" }
        let parts = a.split(separator: "-").map(String.init)
        if parts.count > 1 { return "Presses \(keys(a)) together" }
        if a.count == 1 { return "Types “\(a.uppercased())”" }
        return "Presses the \(keyName(a)) key"
    }

    // MARK: - Tables

    private static func rawCode(_ a: String) -> Int? {
        guard a.hasPrefix("<"), a.hasSuffix(">") else { return nil }
        return Int(a.dropFirst().dropLast())
    }

    /// HID keyboard usages that the CLI has no name for.
    private static let rawNames: [Int: String] = [
        72: "Pause", 71: "Scroll Lock", 70: "Print Screen", 101: "Menu",
    ]

    private static let modifierNames: [String: String] = [
        "ctrl": "Ctrl", "shift": "Shift", "alt": "Alt (⌥)", "opt": "⌥ Option",
        "win": "Win", "cmd": "⌘ Cmd", "rctrl": "Right Ctrl", "rshift": "Right Shift",
        "ralt": "Right Alt", "ropt": "Right Option", "rwin": "Right Win", "rcmd": "Right ⌘",
    ]

    private static let keyNames: [String: String] = [
        "enter": "Enter", "escape": "Esc", "backspace": "Backspace", "tab": "Tab",
        "space": "Space", "minus": "−", "equal": "=", "leftbracket": "[", "rightbracket": "]",
        "backslash": "\\", "semicolon": ";", "quote": "'", "grave": "`", "comma": ",",
        "dot": ".", "slash": "/", "capslock": "Caps Lock", "printscreen": "Print Screen",
        "insert": "Insert", "home": "Home", "pageup": "Page Up", "delete": "Delete",
        "end": "End", "pagedown": "Page Down", "right": "→", "left": "←", "down": "↓", "up": "↑",
        "numlock": "Num Lock", "numpadslash": "Numpad /", "numpadasterisk": "Numpad *",
        "numpadminus": "Numpad −", "numpadplus": "Numpad +", "numpadenter": "Numpad Enter",
        "numpaddot": "Numpad .", "numpadequal": "Numpad =", "application": "Menu",
        "power": "Power", "play": "Play/Pause", "stop": "Stop", "next": "Next track",
        "prev": "Previous track", "previous": "Previous track", "mute": "Mute",
        "volumeup": "Volume +", "volumedown": "Volume −", "screenlock": "Lock screen",
        "calculator": "Calculator", "favorites": "Favorites",
        "wheelup": "Wheel up", "wheeldown": "Wheel down",
        "click": "Left click", "rclick": "Right click", "mclick": "Middle click",
    ]

    /// Plain-English meanings for common whole actions.
    private static let known: [String: String] = [
        "cmd-c": "Copy", "cmd-v": "Paste", "cmd-x": "Cut", "cmd-z": "Undo",
        "cmd-shift-z": "Redo", "cmd-a": "Select all", "cmd-s": "Save", "cmd-t": "New tab",
        "cmd-w": "Close window/tab", "cmd-q": "Quit app", "cmd-tab": "Switch app",
        "cmd-space": "Spotlight", "ctrl-up": "Mission Control",
        "ctrl-c": "Copy (Windows/Linux)", "ctrl-v": "Paste (Windows/Linux)",
        "ctrl-x": "Cut (Windows/Linux)", "ctrl-z": "Undo (Windows/Linux)",
        "ctrl-alt-del": "Ctrl+Alt+Del security screen",
        "play": "Play / pause media", "stop": "Stop media", "next": "Next track",
        "prev": "Previous track", "previous": "Previous track", "mute": "Mute audio",
        "volumeup": "Volume up", "volumedown": "Volume down",
        "screenlock": "Lock the screen", "calculator": "Open calculator",
        "wheelup": "Scroll up", "wheeldown": "Scroll down",
        "click": "Left mouse click", "rclick": "Right mouse click", "mclick": "Middle mouse click",
        "left": "Left arrow", "right": "Right arrow", "up": "Up arrow", "down": "Down arrow",
        "enter": "Enter / confirm", "escape": "Escape / cancel", "space": "Space bar",
    ]

    private static func keyName(_ k: String) -> String {
        let l = k.lowercased()
        if let m = modifierNames[l] { return m }
        if let n = keyNames[l] { return n }
        if l.hasPrefix("numpad"), let d = Int(l.dropFirst(6)) { return "Numpad \(d)" }
        if l.hasPrefix("f"), Int(l.dropFirst()) != nil { return l.uppercased() }
        return l.count == 1 ? l.uppercased() : k
    }

    private static func mouseText(_ a: String) -> String? {
        let l = a.lowercased()
        let mods = l.split(separator: "-").dropLast().map { keyName(String($0)) }
        let core = String(l.split(separator: "-").last ?? "")
        let prefix = mods.isEmpty ? "" : mods.joined(separator: " + ") + " + "
        let arg = core.drop { $0 != "(" }.dropFirst().dropLast()
        if core.hasPrefix("click") { return prefix + "Click (\(arg))" }
        if core.hasPrefix("wheel") {
            return (Int(arg) ?? 0) >= 0 ? prefix + "Scroll down \(arg)" : prefix + "Scroll up \(arg.dropFirst())"
        }
        if core.hasPrefix("move") { return prefix + "Move pointer (\(arg))" }
        if core.hasPrefix("drag") { return prefix + "Drag (\(arg))" }
        return nil
    }
}
