import SwiftUI
import os

/// M0 scaffold entry point.
@main
struct MicroPadStudioApp: App {
    init() {
        // Launch proof for headless CI-style verification (M0 test).
        FileHandle.standardOutput.write(Data("MICROPADSTUDIO_LAUNCHED pid=\(ProcessInfo.processInfo.processIdentifier)\n".utf8))
    }

    var body: some Scene {
        WindowGroup("MicroPad Studio") {
            ContentView()
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}
