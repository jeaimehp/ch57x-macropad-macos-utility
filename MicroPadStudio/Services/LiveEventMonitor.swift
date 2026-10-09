import Foundation
import IOKit
import IOKit.hid

/// Listens to live HID input events from the micropad (1189:8890) via IOHIDManager.
/// The pad in normal mode enumerates as a plain keyboard, so button presses arrive as
/// ordinary key/consumer/wheel reports — M3 matches these back to slots by action name.
/// Requires Input Monitoring (TCC) permission; `start()` requests it.
final class LiveEventMonitor {
    /// Callbacks fire on the main run loop.
    var onKey: ((String, Bool) -> Void)?          // (keyName, isDown)
    var onWheel: ((Int32) -> Void)?               // signed wheel delta
    var onMouseButton: ((UInt32, Bool) -> Void)?  // (button number 1-based, isDown)
    private(set) var accessGranted = false

    private var manager: IOHIDManager?

    // HID usage → ch57x-keyboard-tool key name (usage tables per HUT 1.12 §10).
    static let keyNames: [UInt32: String] = {
        var m: [UInt32: String] = [:]
        for (i, c) in "abcdefghijklmnopqrstuvwxyz".enumerated() { m[UInt32(4 + i)] = String(c) }
        for (i, c) in "123456789".enumerated() { m[UInt32(0x1E + i)] = String(c) }
        m[0x27] = "0"
        m[0x28] = "enter"; m[0x29] = "escape"; m[0x2A] = "backspace"
        m[0x2B] = "tab";   m[0x2C] = "space"
        for i in 0..<12 { m[UInt32(0x3A + i)] = "f\(i + 1)" }
        m[0x4A] = "home"; m[0x4B] = "pageup"; m[0x4C] = "delete"; m[0x4D] = "end"; m[0x4E] = "pagedown"
        m[0x4F] = "right"; m[0x50] = "left"; m[0x51] = "down"; m[0x52] = "up"
        return m
    }()

    static let consumerNames: [UInt32: String] = [
        0xCD: "play", 0xB7: "stop", 0xB5: "next", 0xB6: "prev",
        0xE2: "mute", 0xE9: "volumeup", 0xEA: "volumedown",
        0x8A: "calculator", 0x9E: "screenlock" /* power */,
    ]

    @discardableResult
    func start() -> Bool {
        stop()
        // Ask TCC for listen access (presents prompt on first run; false ⇒ no events will flow).
        accessGranted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)

        let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let match: [String: Any] = [kIOHIDVendorIDKey: 0x1189, kIOHIDProductIDKey: 0x8890]
        IOHIDManagerSetDeviceMatching(m, match as CFDictionary)
        IOHIDManagerRegisterInputValueCallback(m, { ctx, _, _, valueRef in
            guard let ctx else { return }
            let monitor = Unmanaged<LiveEventMonitor>.fromOpaque(ctx).takeUnretainedValue()
            monitor.handle(value: valueRef)
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerOpen(m, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerScheduleWithRunLoop(m, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        manager = m
        return accessGranted
    }

    func stop() {
        if let m = manager {
            IOHIDManagerUnscheduleFromRunLoop(m, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDManagerClose(m, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        manager = nil
    }

    private func handle(value valueRef: IOHIDValue) {
        let element = IOHIDValueGetElement(valueRef)
        let page = IOHIDElementGetUsagePage(element)
        let usage = IOHIDElementGetUsage(element)
        let v = IOHIDValueGetIntegerValue(valueRef)

        switch page {
        case 0x07, 0x04: // Keyboard/Keypad, Generic Desktop keys
            guard let name = Self.keyNames[usage] else { return }
            onKey?(name, v != 0)
        case 0x0C:       // Consumer (media keys)
            guard let name = Self.consumerNames[usage] else { return }
            onKey?(name, v != 0)
        case 0x01:       // Generic Desktop: wheel / AC pan
            if usage == 0x38 || usage == 0x48 { onWheel?(Int32(v)) }
        case 0x02:       // Mouse buttons (knob press emits a mouse click)
            onMouseButton?(usage, v != 0)
        default:
            break
        }
    }
}
