import SwiftUI

/// M1 shell: device status + validate/upload + YAML preview. Editor lands in M2.
struct ContentView: View {
    @StateObject private var store = MappingStore()
    @State private var confirmUpload = false
    @State private var showLibrary = false
    @State private var showImporter = false
    @State private var showExporter = false

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
                Button {
                    showLibrary.toggle()
                } label: {
                    Label(store.activeConfigName ?? "Unsaved", systemImage: "square.stack")
                }
                .popover(isPresented: $showLibrary, arrowEdge: .bottom) {
                    ConfigLibraryView(store: store)
                }
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
                // Visual pad editor (M2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Editor").font(.headline)
                    PadEditorView(store: store)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

                Divider()

                // Action inspector (M2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Action").font(.headline)
                    ActionInspectorView(store: store)
                        .id(store.selection.map { "\($0)" })  // reset filter/custom per selection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

                Divider()

                // Live YAML preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("mapping.yaml").font(.headline)
                    Picker("Orientation", selection: Binding(
                        get: { store.mapping.orientation },
                        set: { store.mapping.orientation = $0 })) {
                        ForEach(PadMapping.Orientation.allCases) { o in
                            Text(o.rawValue.capitalized).tag(o)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
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
