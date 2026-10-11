import SwiftUI

/// Inspector for the selected slot: category tabs + action grid + custom entry. M2.
struct ActionInspectorView: View {
    @ObservedObject var store: MappingStore
    @State private var category: ActionCategory = .common
    @State private var search = ""
    @State private var custom = ""

    private var items: [(display: String, action: String)] {
        let base = ActionsCatalog.items(for: category)
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter { $0.display.lowercased().contains(q) || $0.action.lowercased().contains(q) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let slot = store.selection {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.slotLabel(slot)).font(.headline).lineLimit(1)
                        Text("current: \(store.action(for: slot))")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 4)
                    Button("Done") { store.selection = nil }
                        .fixedSize()
                }

                // Segmented pickers NEVER shrink below their intrinsic width (~380pt for
                // 5 segments) and clip the whole window when selected. ViewThatFits keeps
                // the segmented look only when it actually fits; otherwise compact menu.
                ViewThatFits(in: .horizontal) {
                    Picker("Category", selection: $category) {
                        ForEach(ActionCategory.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Category", selection: $category) {
                        ForEach(ActionCategory.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                TextField("Filter…", text: $search)
                    .textFieldStyle(.roundedBorder)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 6)], spacing: 6) {
                        ForEach(items, id: \.action) { item in
                            Button(item.display) {
                                store.assign(item.action, to: slot)
                            }
                            .buttonStyle(.bordered)
                            .help(item.action)
                        }
                    }
                    .padding(.vertical, 2)
                }

                HStack {
                    TextField("Custom action (combo/sequence/mouse)…", text: $custom)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(applyCustom)
                    Button("Apply") { applyCustom() }
                        .disabled(custom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Text("Combos: ctrl-c · Sequences: h,i · Mouse: click(left), move(10,0) · Raw: <101>")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)   // wrap, never widen the column
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "hand.tap").font(.title2).foregroundStyle(.secondary)
                    Text("Select a button or knob segment to edit its action")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func applyCustom() {
        let v = custom.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty, let slot = store.selection else { return }
        store.assign(v, to: slot)
        custom = ""
    }
}
