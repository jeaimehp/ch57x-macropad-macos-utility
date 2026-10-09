import SwiftUI

/// Visual pad: 3×2 button grid + knob for the active layer. M2.
struct PadEditorView: View {
    @ObservedObject var store: MappingStore

    var body: some View {
        VStack(spacing: 10) {
            // Layer tabs
            Picker("Layer", selection: $store.currentLayer) {
                ForEach(0..<store.mapping.layers.count, id: \.self) { i in
                    Text("Layer \(i + 1)").tag(i)
                }
            }
            .pickerStyle(.segmented)
            .disabled(store.isBusy)

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

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func padButton(row: Int, col: Int) -> some View {
        let slot = MappingStore.Slot.button(row: row, col: col)
        let selected = store.selection == slot
        Button {
            store.selection = slot
        } label: {
            VStack(spacing: 3) {
                Text("\(row + 1)·\(col + 1)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Text(store.action(for: slot))
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
            }
            .frame(width: 96, height: 72)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selected ? Color.accentColor.opacity(0.25) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.35),
                                  lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .help("Row \(row + 1), column \(col + 1)")
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
        Button {
            store.selection = slot
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 10))
                Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
                Spacer(minLength: 2)
                Text(store.action(for: slot))
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 8)
            .frame(width: 150, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? Color.accentColor.opacity(0.25) : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(selected ? Color.accentColor : Color.secondary.opacity(0.35),
                                  lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
