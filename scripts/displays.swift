import CoreGraphics
var count: UInt32 = 0
CGGetActiveDisplayList(8, nil, &count)
var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
CGGetActiveDisplayList(8, &ids, &count)
for id in ids {
    let b = CGDisplayBounds(id)
    print("display \(id): x=\(b.origin.x) y=\(b.origin.y) w=\(b.size.width) h=\(b.size.height)")
}
