import Foundation
import IOKit.usb
import Combine

/// Polls IOKit for CH57x macro pads (vendor 0x1189; products 8890/8840/8842).
/// Polling (1s) is intentional: far simpler than IONotifier plumbing and cheap.
final class DeviceMonitor: ObservableObject {
    @Published private(set) var connected = false
    @Published private(set) var productID: UInt16?

    static let vendorID: UInt16 = 0x1189
    static let productIDs: [UInt16] = [0x8890, 0x8840, 0x8842]

    private var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    func stop() { timer?.invalidate(); timer = nil }

    func refresh() {
        var found = false
        var foundProduct: UInt16?
        for pid in Self.productIDs {
            if let service = Self.matchingService(vendor: Self.vendorID, product: pid) {
                IOObjectRelease(service)
                found = true
                foundProduct = pid
                break
            }
        }
        if found != connected || foundProduct != productID {
            connected = found
            productID = foundProduct
        }
    }

    private static func matchingService(vendor: UInt16, product: UInt16) -> io_service_t? {
        guard let matching = IOServiceMatching(kIOUSBDeviceClassName) else { return nil }
        // IOServiceMatching returns a create-rule dict; add criteria directly.
        CFDictionarySetValue(matching,
                             Unmanaged.passUnretained("idVendor" as CFString).toOpaque(),
                             Unmanaged.passUnretained(NSNumber(value: vendor)).toOpaque())
        CFDictionarySetValue(matching,
                             Unmanaged.passUnretained("idProduct" as CFString).toOpaque(),
                             Unmanaged.passUnretained(NSNumber(value: product)).toOpaque())
        var iterator: io_iterator_t = 0
        // IOServiceGetMatchingServices consumes `matching` (owns it after this call).
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }
        let service = IOIteratorNext(iterator)
        if service == 0 { return nil }
        return service
    }
}
