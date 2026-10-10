import Testing
@testable import MicroPadCore

@Suite("core sanity")
struct CoreTests {
    @Test func versionPresent() {
        #expect(!MicroPadCore.version.isEmpty)
    }
}
