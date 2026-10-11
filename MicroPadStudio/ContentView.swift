import SwiftUI
import UniformTypeIdentifiers

/// FileDocument shim so `.fileExporter` can save plain YAML text (M5).
struct YAMLDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.yaml, .plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = String(decoding: data, as: UTF8.self)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

/// M1 shell: device status + validate/upload + YAML preview. Editor lands in M2.
struct ContentView: View {
    @StateObject private var store: MappingStore
    @State private var confirmUpload = false
    @State private var showLibrary = false
    @State private var showTemplates = false
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var exportDoc: YAMLDocument?

    init() {
        // Test hook (--layout-test --select-key): open the app with a key already
        // selected so the headless layout test can measure the inspector-open state.
        _store = StateObject(wrappedValue: {
            let s = MappingStore()
            if CommandLine.arguments.contains("--select-key") { s.selection = .button(row: 0, col: 0) }
            return s
        }())
    }

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
                Button {
                    showTemplates = true
                } label: {
                    Label("Templates", systemImage: "rectangle.grid.3x2")
                }
                .disabled(store.isBusy)
                Button { store.device.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .help("Re-scan for the pad")
                    .disabled(store.isBusy)
                Button("Import…") { showImporter = true }
                    .disabled(store.isBusy)
                Button("Export…") {
                    exportDoc = YAMLDocument(text: store.yamlText)
                    showExporter = true
                }
                .disabled(store.isBusy)
                Button("Validate") { store.validate() }
                    .disabled(store.isBusy)
                Button("Upload to Pad…") { confirmUpload = true }
                    .disabled(store.isBusy || !store.device.connected)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)
            .background(
                LinearGradient(colors: [Color(red: 0.13, green: 0.40, blue: 0.98).opacity(0.22),
                                        Color(red: 0.42, green: 0.27, blue: 0.95).opacity(0.18),
                                        Color(red: 0.74, green: 0.24, blue: 0.86).opacity(0.22)],
                               startPoint: .leading, endPoint: .trailing)
            )
            Divider()

            HStack(spacing: 0) {
                // Visual pad editor (M2). Hard floor: grid (3×96+spacings) + knob (150)
                // + paddings must never be compressed — layoutPriority keeps the pad
                // on-screen when the inspector/yaml columns compete for width.
                VStack(alignment: .leading, spacing: 4) {
                    Label("Editor", systemImage: "square.grid.3x2.fill").font(.headline)
                        .foregroundStyle(Self.accent)
                    PadEditorView(store: store)
                }
                .frame(minWidth: 500, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(2)
                .padding()

                Divider()

                // Action inspector (M2)
                VStack(alignment: .leading, spacing: 4) {
                    Label("Action", systemImage: "wand.and.stars").font(.headline)
                        .foregroundStyle(Color(red: 0.55, green: 0.33, blue: 0.98))
                    ActionInspectorView(store: store)
                        .id(store.selection.map { "\($0)" })  // reset filter/custom per selection
                }
                .frame(minWidth: 230, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                .padding()

                Divider()

                // Live YAML preview
                VStack(alignment: .leading, spacing: 8) {
                    Label("mapping.yaml", systemImage: "doc.text").font(.headline)
                        .foregroundStyle(Color(red: 0.93, green: 0.28, blue: 0.80))
                    Picker("Orientation", selection: Binding(
                        get: { store.mapping.orientation },
                        set: { store.mapping.orientation = $0 })) {
                        ForEach(PadMapping.Orientation.allCases) { o in
                            Text(o.rawValue.capitalized).tag(o)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    ScrollView(.horizontal) {
                        Text(store.yamlText)
                            .font(.system(.caption, design: .monospaced))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)
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
        .tint(Self.accent)
        .sheet(isPresented: $showTemplates) { TemplateGuideView(store: store).tint(Self.accent) }
        .confirmationDialog(
            "Upload will overwrite the mapping currently stored on the pad. This cannot be read back.",
            isPresented: $confirmUpload, titleVisibility: .visible
        ) {
     Button("Upload", role: .destructive) { store.upload() }
     Button("Cancel", role: .cancel) {}
 }
 .fileImporter(isPresented: $showImporter,
               allowedContentTypes: [.yaml, .plainText],
               allowsMultipleSelection: false) { result in
     switch result {
     case .success(let urls):
         if let url = urls.first { store.importConfig(from: url) }
     case .failure(let err):
         store.lastResult = "❌ import failed: \(err.localizedDescription)"
     }
 }
 .fileExporter(isPresented: $showExporter,
               document: exportDoc,
               contentTypes: [.yaml],
               defaultFilename: store.activeConfigName ?? "mapping") { result in
     if case .success(let url) = result { store.exportConfig(to: url) }
     exportDoc = nil
 }
 .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
    guard let provider = providers.first else { return false }
    _ = provider.loadObject(ofClass: URL.self) { url, _ in
        guard let url, ["yaml", "yml"].contains(url.pathExtension.lowercased()) else { return }
        DispatchQueue.main.async { store.importConfig(from: url) }
    }
    return true
}
.onExitCommand { store.selection = nil }   // Esc closes the inspector / restores plain pad view
}

    /// App accent: the icon's blue-violet.
    static let accent = Color(red: 0.36, green: 0.36, blue: 1.0)

    private func hex(_ v: UInt16?) -> String {
        guard let v else { return "??" }
        return String(format: "%04x", v)
    }
}

#Preview {
    ContentView()
}
