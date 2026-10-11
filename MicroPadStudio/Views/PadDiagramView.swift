import SwiftUI

/// Read-only picture of the pad with each control's function printed where it
/// physically sits. Numbered badges match the rows of the guide's listing.
struct PadDiagramView: View {
    let mapping: PadMapping
    var layer: Int = 0

    /// Keycap colours, row-major — the same rainbow as the app icon.
    static let palette: [Color] = [
        Color(red: 0.16, green: 0.49, blue: 1.00), Color(red: 0.55, green: 0.33, blue: 0.98),
        Color(red: 0.93, green: 0.28, blue: 0.80), Color(red: 0.20, green: 0.78, blue: 0.40),
        Color(red: 0.98, green: 0.70, blue: 0.13), Color(red: 1.00, green: 0.38, blue: 0.23),
    ]

    private var controls: [PadControl] { PadControls.list(mapping, layer: layer) }

    var body: some View {
        let all = controls
        let buttons = all.filter { if case .button = $0.kind { return true } else { return false } }
        let knob = all.filter { if case .knob = $0.kind { return true } else { return false } }
        HStack(alignment: .center, spacing: 18) {
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(0..<mapping.rows, id: \.self) { r in
                    GridRow {
                        ForEach(0..<mapping.columns, id: \.self) { c in
                            if let ctl = buttons.first(where: { $0.kind == .button(row: r, col: c) }) {
                                keycap(ctl)
                            }
                        }
                    }
                }
            }
            if knob.count == 3 { knobView(ccw: knob[0], press: knob[1], cw: knob[2]) }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [Color(white: 0.24), Color(white: 0.13)],
                                     startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        )
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.white.opacity(0.08)))
    }

    private func keycap(_ c: PadControl) -> some View {
        let color = Self.palette[(c.number - 1) % Self.palette.count]
        return VStack(alignment: .leading, spacing: 3) {
            badge(c.number)
            Spacer(minLength: 0)
            Text(c.label)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2).minimumScaleFactor(0.75)
            Text(c.keys)
                .font(.system(size: 10, design: .monospaced))
                .opacity(0.85).lineLimit(1).minimumScaleFactor(0.7)
        }
        .foregroundStyle(.white)
        .padding(8)
        .frame(width: 112, height: 84, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [color.opacity(0.95), color.opacity(0.65)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: color.opacity(0.55), radius: 6)
        )
        .help("\(c.position): \(c.label)\(c.detail.isEmpty ? "" : " — \(c.detail)")")
    }

    private func knobView(ccw: PadControl, press: PadControl, cw: PadControl) -> some View {
        VStack(spacing: 8) {
            knobLabel(cw, symbol: "arrow.clockwise")
            ZStack {
                Circle().fill(RadialGradient(colors: [Color(white: 0.35), Color(white: 0.08)],
                                             center: .topLeading, startRadius: 2, endRadius: 60))
                Circle().strokeBorder(Color(red: 0.25, green: 0.45, blue: 1.0), lineWidth: 3)
                    .shadow(color: .blue.opacity(0.7), radius: 5)
                VStack(spacing: 2) {
                    badge(press.number)
                    Text(press.label)
                        .font(.system(size: 10, weight: .semibold))
                        .lineLimit(2).minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white)
                .padding(10)
            }
            .frame(width: 78, height: 78)
            .help("\(press.position): \(press.label)")
            knobLabel(ccw, symbol: "arrow.counterclockwise")
        }
        .frame(width: 150)
    }

    private func knobLabel(_ c: PadControl, symbol: String) -> some View {
        HStack(spacing: 5) {
            badge(c.number)
            Image(systemName: symbol).font(.system(size: 11, weight: .bold))
            VStack(alignment: .leading, spacing: 0) {
                Text(c.label).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                Text(c.keys).font(.system(size: 9, design: .monospaced)).opacity(0.75).lineLimit(1)
            }
            .minimumScaleFactor(0.7)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .help("\(c.position): \(c.label)\(c.detail.isEmpty ? "" : " — \(c.detail)")")
    }

    private func badge(_ n: Int) -> some View {
        Text("\(n)")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .frame(width: 16, height: 16)
            .background(Circle().fill(Color.black.opacity(0.35)))
            .foregroundStyle(.white)
    }
}
