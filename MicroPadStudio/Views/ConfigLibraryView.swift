import SwiftUI

/// M4: named config library (popover from the top bar).
struct ConfigLibraryView: View {
    @ObservedObject var store: MappingStore
    @State private var newName = ""
    @State private var renaming: String?
    @State private var renameText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button("New") { store.newConfig() }
                Spacer()
                if let active = store.activeConfigName {
                    Button("Save") { store.saveConfig() }
                    Button("Save As…") { newName = active + " 2" }
                } else {
                    Button("Save As…") { newName = "" }
                }
            }
            .controlSize(.small)

            HStack(spacing: 4) {
                TextField("config name", text: $newName)
                    .textFieldStyle(.roundedBorder).controlSize(.small)
                Button("Save") {
                    guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    store.saveConfigAs(newName); newName = ""
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Divider()

            if store.libraryEntries.isEmpty {
                Text("No saved configs yet.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(store.libraryEntries) { entry in
                            row(entry)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(10)
        .frame(width: 320)
    }

    @ViewBuilder
    private func row(_ entry: ConfigLibrary.Entry) -> some View {
        let active = store.activeConfigName == entry.name
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: active ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(active ? Color.accentColor : Color.secondary.opacity(0.4))
                Text(entry.name)
                    .fontWeight(active ? .semibold : .regular)
                Spacer()
                Menu {
                    Button("Apply") { store.applyConfig(entry.name) }
                    Button("Duplicate") { store.duplicateConfig(entry.name) }
                    Button("Rename…") { renaming = entry.name; renameText = entry.name }
                    Divider()
                    Button("Delete", role: .destructive) { store.deleteConfig(entry.name) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(active ? Color.accentColor.opacity(0.12) : .clear,
                        in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .onTapGesture { store.applyConfig(entry.name) }

            if renaming == entry.name {
                HStack(spacing: 4) {
                    TextField("new name", text: $renameText).textFieldStyle(.roundedBorder).controlSize(.small)
                    Button("OK") {
                        guard !renameText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        store.renameConfig(entry.name, to: renameText); renaming = nil
                    }.controlSize(.small).keyboardShortcut(.defaultAction)
                    Button("Cancel") { renaming = nil }.controlSize(.small)
                }
                .padding(.horizontal, 6).padding(.bottom, 4)
            }
        }
    }
}
