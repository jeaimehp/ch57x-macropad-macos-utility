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

            // Pad body: dark rounded plate like the Templates guide diagram.
            HStack(alignment: .center, spacing: 16) {
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
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [Color(white: 0.22), Color(white: 0.11)],
                                         startPoint: .top, endPoint: .bottom))
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
            )
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.08)))

            LiveTestPanelView(store: store)

            Spacer(minLength: 0)
        }
    }

    /// Keycap colour for a grid position — same rainbow as the icon, guide and printed labels.
    private func keyColor(row: Int, col: Int) -> Color {
        PadDiagramView.palette[(row * store.mapping.columns + col) % PadDiagramView.palette.count]
    }

    @ViewBuilder
    private func padButton(row: Int, col: Int) -> some View {
        let slot = MappingStore.Slot.button(row: row, col: col)
        let selected = store.selection == slot
        let pressed = store.isSlotPressed(slot)
        let color = keyColor(row: row, col: col)
        Button {
            // Re-clicking the selected key deselects (escape hatch back to the plain pad view).
            store.selection = (store.selection == slot) ? nil : slot
        } label: {
            VStack(spacing: 3) {
                if let label = store.note(for: slot)?.label, !label.isEmpty {
                    Text(label)
                        .font(.system(size: 10, weight: .bold))
                        .lineLimit(1).minimumScaleFactor(0.7)
                } else {
                    Text("\(row + 1)·\(col + 1)")
                        .font(.system(size: 9, weight: .semibold))
                        .opacity(0.7)
                }
                Text(store.action(for: slot))
                    .font(.system(.body, design: .monospaced).weight(.medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 0.5)
            .frame(width: 92, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 11)
                    .fill(LinearGradient(colors: [color.opacity(pressed ? 1 : 0.95),
                                                  color.opacity(pressed ? 0.9 : 0.62)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: color.opacity(pressed ? 0.95 : 0.5), radius: pressed ? 12 : 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(Color.white.opacity(selected || pressed ? 0.95 : 0.12),
                                  lineWidth: selected || pressed ? 2.5 : 1)
            )
            .scaleEffect(pressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.12), value: pressed)
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
        let glow = FaceplateSheetView.knobGlow
        Button {
            store.selection = (store.selection == slot) ? nil : slot
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 10, weight: .bold)).foregroundStyle(glow)
                Text(store.note(for: slot)?.label.nilIfEmpty ?? label)
                    .font(.system(size: 9, weight: .semibold)).foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                Text(store.action(for: slot))
                    .font(.system(.caption, design: .monospaced).weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 8)
            .frame(width: 142, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(pressed ? glow.opacity(0.55) : Color(white: 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(selected || pressed ? Color.white : glow.opacity(0.7),
                                  lineWidth: selected || pressed ? 2.5 : 1.2)
                    .shadow(color: glow.opacity(0.8), radius: 4)
            )
            .animation(.easeOut(duration: 0.12), value: pressed)
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
