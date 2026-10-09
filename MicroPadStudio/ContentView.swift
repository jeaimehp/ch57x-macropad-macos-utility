import SwiftUI

/// M1 shell: device status + validate/upload + YAML preview. Editor lands in M2.
struct ContentView: View {
    @StateObject private var store = MappingStore()
    @State private var confirmUpload = false

    var body: some View {
        VStack(spacing: 0) {
            // Device status bar
            HStack(spacing: 12) {
                Circle()
                    .fill(store.device.connected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(store.device.connected
                     ? "Micropad connected (\(hex(store.device.productID)))"
                     : "Micropad not detected — plug it in via USB")
                    .font(.callout)
                Spacer()
                Button("Re-scan") { store.device.refresh() }
                    .disabled(store.isBusy)
                Button("Validate") { store.validate() }
                    .disabled(store.isBusy)
                Button("Upload to Pad…") { confirmUpload = true }
                    .disabled(store.isBusy || !store.device.connected)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
            Divider()

            HStack(spacing: 0) {
                // Editor zone (M2)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Editor").font(.headline)
                    Text("Visual pad editor lands here in M2")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

                Divider()

                // Live YAML preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("mapping.yaml").font(.headline)
                    ScrollView {
                        Text(store.yamlText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }

            Divider()

            // Result / log line
            HStack {
                Text(store.lastResult ?? "Idle.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(store.lastResult?.hasPrefix("❌") == true ? Color.red : .primary)
                    .textSelection(.enabled)
                Spacer()
            }
            .padding(8)
            .frame(minHeight: 36)
        }
        .confirmationDialog(
            "Upload will overwrite the mapping currently stored on the pad. This cannot be read back.",
            isPresented: $confirmUpload, titleVisibility: .visible
        ) {
            Button("Upload", role: .destructive) { store.upload() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func hex(_ v: UInt16?) -> String {
        guard let v else { return "??" }
        return String(format: "%04x", v)
    }
}

#Preview {
    ContentView()
}
