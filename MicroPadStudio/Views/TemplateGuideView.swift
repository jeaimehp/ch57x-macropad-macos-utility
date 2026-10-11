import SwiftUI
import AppKit

/// "Templates" sheet: browse built-in templates, saved library configs and the
/// current editor mapping. Each shows a pictorial pad + a numbered listing that
/// explains what every button / knob action does.
struct TemplateGuideView: View {
    @ObservedObject var store: MappingStore
    @Environment(\.dismiss) private var dismiss

    enum Source: Hashable {
        case template(String)   // PadTemplate.id
        case saved(String)      // library entry name
        case editor
    }

    @State private var selection: Source? = .editor
    @State private var layer = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 210)
                Divider()
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            footer
        }
        .frame(width: 900, height: 620)
        .onAppear {
            store.refreshLibrary()
            if let first = store.templates.first { selection = .template(first.id) }
        }
        .onChange(of: selection) { _ in layer = 0 }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            Section("Built-in Templates") {
                if store.templates.isEmpty {
                    Text("None bundled").foregroundStyle(.secondary)
                }
                ForEach(store.templates) { t in
                    Label(t.name, systemImage: "square.grid.3x2").tag(Source.template(t.id))
                }
            }
            Section("Saved Configs") {
                if store.libraryEntries.isEmpty {
                    Text("Nothing saved yet").foregroundStyle(.secondary)
                }
                ForEach(store.libraryEntries) { e in
                    Label(e.name, systemImage: store.activeConfigName == e.name ? "checkmark.circle.fill" : "doc")
                        .tag(Source.saved(e.name))
                }
            }
            Section("Editor") {
                Label("Current editor", systemImage: "slider.horizontal.3").tag(Source.editor)
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Detail

    private var resolved: (name: String, mapping: PadMapping)? {
        switch selection {
        case .template(let id):
            return store.templates.first { $0.id == id }.map { ($0.name, $0.mapping) }
        case .saved(let name):
            return (try? store.library.load(name)).map { (name, $0) }
        case .editor:
            return (store.activeConfigName.map { "Current editor — \($0)" } ?? "Current editor (unsaved)",
                    store.mapping)
        case nil:
            return nil
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let (name, m) = resolved {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(m.title ?? name).font(.title2.bold())
                        if let s = m.summary { Text(s).foregroundStyle(.secondary) }
                    }
                    if m.layers.count > 1 {
                        Picker("Layer", selection: $layer) {
                            ForEach(0..<m.layers.count, id: \.self) { Text("Layer \($0 + 1)").tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .fixedSize()
                    }
                    PadDiagramView(mapping: m, layer: min(layer, m.layers.count - 1))
                        .frame(maxWidth: .infinity)
                    listing(PadControls.list(m, layer: min(layer, m.layers.count - 1)))
                    if m.notes.isEmpty {
                        Text("This config has no notes, so explanations are generated from the key names. Add your own in the editor: select a key and fill in Function / Explanation.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
            }
        } else {
            Text("Select a template or config").foregroundStyle(.secondary)
        }
    }

    private func listing(_ controls: [PadControl]) -> some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                Text("#"); Text("Control"); Text("Keys"); Text("Function")
            }
            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Divider().gridCellUnsizedAxes(.horizontal)
            ForEach(controls) { c in
                GridRow {
                    Text("\(c.number)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(swatch(c)))
                    Text(c.position).font(.callout)
                    Text(c.keys).font(.system(.callout, design: .monospaced))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.label).font(.callout.weight(.semibold))
                        if !c.detail.isEmpty {
                            Text(c.detail).font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func swatch(_ c: PadControl) -> Color {
        if case .knob = c.kind { return Color(white: 0.3) }
        return PadDiagramView.palette[(c.number - 1) % PadDiagramView.palette.count]
    }

    // MARK: - Labels PDF

    private func printLabels(_ style: LabelSheetPDF.Style) {
        guard let (name, m) = resolved else { return }
        let title = m.title ?? name
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(ConfigLibrary.sanitize(title)) \(style == .faceplate ? "faceplate" : "labels").pdf"
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try LabelSheetPDF.write(mapping: m, title: title, style: style, to: url)
            NSWorkspace.shared.open(url)     // opens in Preview, ready to print (⌘P)
            store.lastResult = "🖨 label sheet saved: \(url.lastPathComponent) — print at 100 %"
        } catch {
            store.lastResult = "❌ couldn't create PDF: \(error.localizedDescription)"
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            switch selection {
            case .template(let id):
                if let t = store.templates.first(where: { $0.id == id }) {
                    Button("Load into Editor") { store.loadTemplate(t); dismiss() }
                    Button("Save to Library") { store.saveTemplateToLibrary(t) }
                }
            case .saved(let name):
                Button("Load into Editor") { store.applyConfig(name); dismiss() }
            default:
                EmptyView()
            }
            Menu {
                Button("Keycap Stickers, Knob Legend & Desk Card…") { printLabels(.stickers) }
                Button("Faceplate Overlay & Tape-on Strips…") { printLabels(.faceplate) }
            } label: {
                Label("Print Labels (PDF)", systemImage: "printer")
            }
            .fixedSize()
            .disabled(resolved == nil)
            .help("Make a printable, true-size label sheet for this config")
            Spacer()
            Text("Loading only changes the editor — use Upload to Pad to flash it.")
                .font(.caption).foregroundStyle(.secondary)
            Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
        }
        .padding(12)
    }
}
