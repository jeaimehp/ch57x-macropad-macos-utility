import SwiftUI

/// M0 placeholder shell — shows the planned 3-zone layout.
struct ContentView: View {
    var body: some View {
        HStack(spacing: 0) {
            // Editor zone (M2): visual 3x2 + knob pad, layer tabs
            VStack(alignment: .leading, spacing: 8) {
                Text("Editor").font(.headline)
                Text("Pad editor lands here (M2)")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            Divider()

            // Test + library zone (M3/M4)
            VStack(alignment: .leading, spacing: 8) {
                Text("Live Test · Config Library").font(.headline)
                Text("HID monitor (M3) and saved configs (M4) land here")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("M0 scaffold")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
