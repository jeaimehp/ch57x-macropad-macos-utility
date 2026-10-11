import SwiftUI

/// MicroPad Menu: menu bar helper (no Dock icon, LSUIElement) for one-click switching
/// of the pad between built-in templates and saved configs.
@main
struct MicroPadMenuApp: App {
    @StateObject private var model: MenuModel

    init() {
        if CommandLine.arguments.contains("--selftest") { MenuSelftest.run() }   // exits
        _model = StateObject(wrappedValue: MenuModel())
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            Image(systemName: model.flashing != nil ? "arrow.triangle.2.circlepath"
                  : model.device.connected ? "rectangle.grid.3x2.fill" : "rectangle.grid.3x2")
        }
        .menuBarExtraStyle(.menu)
    }
}

struct MenuContent: View {
    @ObservedObject var model: MenuModel

    var body: some View {
        Text(model.device.connected ? "Pad connected" : "Pad not connected")
        if let state = model.padState {
            Text("On pad: \(state.name) — \(state.flashedAt.formatted(.relative(presentation: .named)))")
        } else {
            Text("On pad: unknown (not flashed from MicroPad yet)")
        }
        if let name = model.flashing {
            Text("⏳ Flashing “\(name)”… don't unplug the pad")
        } else if let msg = model.lastMessage {
            Text(msg)
        }

        Divider()
        Section("Templates") {
            ForEach(model.templates) { itemMenu($0) }
        }
        Section("Saved Configs") {
            if model.saved.isEmpty { Text("None — save one in MicroPad Studio") }
            ForEach(model.saved) { itemMenu($0) }
        }

        Divider()
        Button("Open MicroPad Studio…") { model.openStudio() }
        Toggle("Ask Before Flashing", isOn: $model.askBeforeFlashing)
        Toggle("Launch at Login", isOn: Binding(get: { model.launchAtLogin },
                                                set: { model.launchAtLogin = $0 }))
        Divider()
        Button("Quit MicroPad Menu") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    /// Submenu per config: Flash action first, then a cheat sheet of every control.
    @ViewBuilder
    private func itemMenu(_ item: MenuModel.Item) -> some View {
        let onPad = model.isOnPad(item)
        Menu {
            Button(onPad ? "Flash Again" : "Flash to Pad") { model.requestFlash(item) }
                .disabled(model.flashing != nil || !model.device.connected)
            Divider()
            ForEach(PadControls.list(item.mapping)) { c in
                Text("\(c.number)  \(c.label) — \(c.keys)")
            }
        } label: {
            if onPad { Label(item.name, systemImage: "checkmark") } else { Text(item.name) }
        }
    }
}
