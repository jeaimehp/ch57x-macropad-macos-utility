import SwiftUI
import MicroPadCore

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.3x2.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("MicroPad Studio v\(MicroPadCore.version)")
                .font(.title2)
            Text("scaffold — editor coming in M2")
                .foregroundStyle(.tertiary)
        }
        .padding(40)
    }
}
