import Foundation

/// Static vocabulary of ch57x-keyboard-tool actions (verified against
/// `ch57x-keyboard-tool show-keys` v1.7.0 and doc/actions.md @ master).
/// The authoritative validation is always the CLI `validate` — this catalog
/// only drives the picker UI.
enum ActionCategory: String, CaseIterable, Identifiable {
    case common, keys, media, mouse, advanced
    var id: String { rawValue }
    var label: String {
        switch self {
        case .common: return "Common"
        case .keys: return "Keys"
        case .media: return "Media"
        case .mouse: return "Mouse"
        case .advanced: return "Advanced"
        }
    }
}

struct ActionsCatalog {
    /// Single key names (output of `show-keys`, in tool order).
    static let keys: [String] = [
        "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
        "1","2","3","4","5","6","7","8","9","0",
        "enter","escape","backspace","tab","space","minus","equal",
        "leftbracket","rightbracket","backslash","nonushash","semicolon","quote","grave","comma","dot","slash",
        "capslock",
        "f1","f2","f3","f4","f5","f6","f7","f8","f9","f10","f11","f12",
        "printscreen","macbrightnessdown","macbrightnessup",
        "insert","home","pageup","delete","end","pagedown",
        "right","left","down","up",
        "numlock","numpadslash","numpadasterisk","numpadminus","numpadplus","numpadenter",
        "numpad1","numpad2","numpad3","numpad4","numpad5","numpad6","numpad7","numpad8","numpad9","numpad0","numpaddot",
        "nonusbackslash","application","power","numpadequal",
        "f13","f14","f15","f16","f17","f18","f19","f20","f21","f22","f23","f24",
    ]

    static let media: [String] = [
        "play","stop","next","prev","mute","volumeup","volumedown",
        "screenbrightnessup","screenbrightnessdown",
        "favorites","calculator","screenlock",
        "webpagehome","webpageback","webpageforward",
    ]

    static let mousePresets: [String] = [
        "click","rclick","mclick","click(left+right)",
        "wheelup","wheeldown","wheel(5)","wheel(-5)",
        "move(10,0)","move(-10,0)","move(0,10)","move(0,-10)",
        "drag(left,10,0)","drag(right,10,0)",
        "ctrl-click(left)","shift-click(left)",
    ]

    static let common: [(display: String, action: String)] = [
        ("copy", "cmd-c"), ("paste", "cmd-v"), ("cut", "cmd-x"),
        ("undo", "cmd-z"), ("redo", "cmd-shift-z"), ("select all", "cmd-a"),
        ("save", "cmd-s"), ("new tab", "cmd-t"),
        ("spotlight", "cmd-space"), ("mission control", "ctrl-up"), ("app switch", "cmd-tab"),
        ("enter", "enter"), ("escape", "escape"), ("backspace", "backspace"),
        ("space", "space"), ("delete", "delete"), ("tab", "tab"),
    ]

    /// Common copy-paste style combos for the Keys tab quick row.
    static let combos: [String] = [
        "cmd-c","cmd-v","cmd-x","cmd-z","cmd-a","cmd-s","cmd-tab","cmd-space",
        "ctrl-c","ctrl-v","ctrl-x","ctrl-z","ctrl-alt-del",
        "shift-tab","cmd-q","cmd-w","cmd-m",
    ]

    static let advanced: [String] = [
        "<101>",                       // raw HID usage code
        "{delay(100)}left,right",      // delayed sequence
        "h,e,l,l,o",                   // typed sequence (≤5 accords)
        "ctrl-a,ctrl-c",               // sequence of combos
    ]

    static func items(for category: ActionCategory) -> [(display: String, action: String)] {
        switch category {
        case .common:   return common.map { ($0.0, $0.1) }
        case .keys:     return (combos + keys).map { ($0, $0) }
        case .media:    return media.map { ($0, $0) }
        case .mouse:    return mousePresets.map { ($0, $0) }
        case .advanced: return advanced.map { ($0, $0) }
        }
    }
}
