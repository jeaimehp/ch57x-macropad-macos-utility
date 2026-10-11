import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
for w in list {
    if let owner = w[kCGWindowOwnerName as String] as? String, owner == "MicroPadStudio" {
        let name = w[kCGWindowName as String] as? String ?? "?"
        let layer = w[kCGWindowLayer as String] ?? -999
        let alpha = w[kCGWindowAlpha as String] ?? -1
        let bounds = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
        print("name=\(name) layer=\(layer) alpha=\(alpha) x=\(bounds["X"] ?? "?") y=\(bounds["Y"] ?? "?") w=\(bounds["Width"] ?? "?") h=\(bounds["Height"] ?? "?")")
    }
}
