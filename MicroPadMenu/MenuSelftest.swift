import Foundation

/// `MicroPad Menu --selftest`: exercises the helper's flash path end-to-end against a
/// FAKE pad tool in a temp support dir — never touches the real pad or real settings.
@MainActor
enum MenuSelftest {
    static func run() -> Never {
        let env = ProcessInfo.processInfo.environment
        guard env["MICROPAD_SUPPORT_DIR"] != nil, env["MICROPAD_TOOL_PATH"] != nil else {
            print("MENU SELFTEST FAIL: run with MICROPAD_SUPPORT_DIR and MICROPAD_TOOL_PATH set (fake tool)")
            exit(2)
        }
        func fail(_ m: String) -> Never { print("MENU SELFTEST FAIL: \(m)"); exit(1) }

        let model = MenuModel()
        guard !model.templates.isEmpty else { fail("no templates bundled") }
        print("MENU SELFTEST templates ok (\(model.templates.count))")

        // Library item appears in the menu model.
        do { _ = try ConfigLibrary().save(model.templates[0].mapping, as: "Selftest Saved") }
        catch { fail("library save: \(error)") }
        model.refresh()
        guard model.saved.contains(where: { $0.name == "Selftest Saved" }) else { fail("saved config not listed") }
        print("MENU SELFTEST library ok")

        // Flash through the fake tool; PadState must record it and mark the item on-pad.
        let item = model.templates.last!
        model.flash(item)
        let deadline = Date().addingTimeInterval(20)
        while model.flashing != nil && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        guard model.flashing == nil else { fail("flash did not finish") }
        guard model.lastMessage?.hasPrefix("✅") == true else { fail("flash result: \(model.lastMessage ?? "nil")") }
        guard PadState.load()?.name == item.name, model.isOnPad(item),
              !model.isOnPad(model.templates.first!) || model.templates.count == 1 else { fail("pad state not recorded") }
        print("MENU SELFTEST flash ok (fake tool, recorded '\(item.name)')")

        // Upload lock: a second uploader must get .busy instead of racing the USB write.
        let fd = open(Ch57xTool.lockURL().path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0, flock(fd, LOCK_EX | LOCK_NB) == 0 else { fail("could not take lock") }
        do {
            try Ch57xTool().upload(MappingYAML.emit(item.mapping))
            fail("upload ran while lock held")
        } catch Ch57xTool.ToolError.busy {
            print("MENU SELFTEST lock ok (concurrent upload refused)")
        } catch { fail("expected busy, got \(error)") }
        close(fd)

        // App hotkeys: lookup by bundle id / name, register + unregister (never fired here).
        guard AppHotKeys.appURL("com.apple.finder") != nil, AppHotKeys.appURL("Calculator") != nil,
              AppHotKeys.appURL("no.such.app.xyz") == nil else { fail("appURL lookup") }
        let hk = AppHotKeys()
        guard hk.update(["f19": "com.apple.finder", "f99": "ignored"]) == 1 else { fail("hotkey register") }
        guard hk.update([:]) == 0 else { fail("hotkey unregister") }
        if let muse = model.templates.first(where: { $0.id == "template:meta-muse-macos" }) {
            guard muse.mapping.apps["f13"] != nil else { fail("Muse template lacks @app f13") }
        }
        print("MENU SELFTEST hotkeys ok (F13–F20 register/unregister, app lookup)")

        print("MENU SELFTEST PASS")
        exit(0)
    }
}
