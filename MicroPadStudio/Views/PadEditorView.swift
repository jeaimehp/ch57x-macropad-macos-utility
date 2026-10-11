import SwiftUI

/// Visual pad: 3×2 button grid + knob for the active layer. M2.
struct PadEditorView: View {
    @ObservedObject var store: MappingStore

    var body: some View {
        VStack(spacing: 10) {
            // Layer tabs — hidden for single-layer configs (pads without a layer-switch button)
            if store.mapping.layers.count > 1 {
                Picker("Layer", selection: $store.currentLayer) {
                    ForEach(0..<store.mapping.layers.count, id: \.self) { i in
                        Text("Layer \(i + 1)").tag(i)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(store.isBusy)
            }

            HStack(alignment: .center, spacing: 22) {
                // 3 columns × 2 rows (knob counted on the right, per project convention)
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    ForEach(0..<store.mapping.rows, id: \.self) { r in
                        GridRow {
                            ForEach(0..<store.mapping.columns, id: \.self) { c in
                                padButton(row: r, col: c)
                            }
                        }
                    }
                }

                knobView
            }
            .padding(.vertical, 6)

            LiveTestPanelView(store: store)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func padButton(row: Int, col: Int) -> some View {
        let slot = MappingStore.Slot.button(row: row, col: col)
        let selected = store.selection == slot
        let pressed = store.isSlotPressed(slot)
        Button {
            // Re-clicking the selected key deselects (escape hatch back to the plain pad view).
            store.selection = (store.selection == slot) ? nil : slot
        } label: {
            VStack(spacing: 3) {
                if let label = store.note(for: slot)?.label, !label.isEmpty {
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1).minimumScaleFactor(0.7)
                } else {
                    Text("\(row + 1)·\(col + 1)")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                Text(store.action(for: slot))
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
            }
            .frame(width: 96, height: 72)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(pressed ? Color.orange.opacity(0.55)
                                  : selected ? Color.accentColor.opacity(0.25)
                                  : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(pressed ? .orange
                                  : selected ? Color.accentColor : Color.secondary.opacity(0.35),
                                  lineWidth: (pressed || selected) ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .help(store.note(for: slot).map { "\($0.label)\($0.detail.isEmpty ? "" : " — \($0.detail)")" }
              ?? "Row \(row + 1), column \(col + 1)")
    }

    @ViewBuilder
    private var knobView: some View {
        VStack(spacing: 6) {
            knobSegment(.knobCW, label: "CW", symbol: "arrow.clockwise")
            knobSegment(.knobPress, label: "Press", symbol: "circle.fill")
            knobSegment(.knobCCW, label: "CCW", symbol: "arrow.counterclockwise")
        }
    }

    @ViewBuilder
    private func knobSegment(_ slot: MappingStore.Slot, label: String, symbol: String) -> some View {
        let selected = store.selection == slot
        let pressed = store.isSlotPressed(slot)
        Button {
            store.selection = (store.selection == slot) ? nil : slot
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 10))
                Text(store.note(for: slot)?.label.nilIfEmpty ?? label)
                    .font(.system(size: 9)).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                Text(store.action(for: slot))
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 8)
            .frame(width: 150, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(pressed ? Color.orange.opacity(0.55)
                                  : selected ? Color.accentColor.opacity(0.25)
                                  : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(pressed ? .orange
                                  : selected ? Color.accentColor : Color.secondary.opacity(0.35),
                                  lineWidth: (pressed || selected) ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Toggle + event feed for the M3 live-test panel (IOHIDManager listen).
struct LiveTestPanelView: View {
    @ObservedObject var store: MappingStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Toggle(isOn: Binding(get: { store.liveOn },
                                     set: { store.setLive(on: $0) })) {
                    Label("Live Test", systemImage: "bolt.horizontal.circle")
                }
                .toggleStyle(.button)
                .controlSize(.small)
                if store.liveOn && !store.liveAccessGranted {
                    Text("⚠︎ grant Input Monitoring in System Settings")
                        .font(.caption2).foregroundStyle(.orange)
                }
                Spacer()
                if !store.liveLog.isEmpty {
                    Button("Clear") { store.liveLog.removeAll() }
                        .controlSize(.small).buttonStyle(.link)
                }
            }
            if !store.liveLog.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(store.liveLog.prefix(12), id: \.self) { line in
                            Text(line).font(.system(.caption2, design: .monospaced))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 70)
            }
        }
        .padding(.top, 2)
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
