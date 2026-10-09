# MicroPad Studio — Milestones (APPROVED 2026-10-09)

macOS SwiftUI app to configure a 3×2 + 1 knob CH57x micropad (USB `1189:8890`),
based on https://github.com/kriomant/ch57x-keyboard-tool

## Architecture decision (v1)

- **Native SwiftUI app** ("MicroPad Studio"), built with Xcode 27 / Swift 6.4 (verified installed).
- **Programming the pad**: reuse the battle-tested `ch57x-keyboard-tool` v1.7.0 binary, bundled inside the .app. The app generates the YAML mapping and pipes it to `validate`/`upload` via `Process` (stdin). No Rust toolchain needed, no protocol reimplementation. (Fallback option C: compile the Rust crate as a C-ABI lib via FFI — only if bundling the CLI proves insufficient.)
- **Live test view**: Swift `IOHIDManager` subscribes directly to device `1189:8890` and surfaces keyboard/mouse HID reports → the GUI highlights buttons/knob in real time. No interference with the tool's write path (writes are short control transfers).
- **Configs**: YAML format identical to ch57x-keyboard-tool (interop for free). Library of named configs in Application Support; import/export via `fileImporter`/`fileExporter`.

## Milestones

### M0 — Scaffold & handoff docs  `(0.5 day)` ✅ DONE
- Xcode project (SwiftUI, macOS 14+), repo layout, `.gitignore`, `pickupandgo.md`, this plan.
- **Test**: app builds & launches empty window. Commit.

### M1 — Core plumbing: model + device + flash  `(1–2 days)` ✅ DONE (final flash test awaits user consent)
- Swift model of the mapping YAML (layers/buttons/knob, `model`, `rows`, `columns`, `knobs`, `orientation`).
- Bundle `ch57x-keyboard-tool` binary; device detection (USB 1189:8890 present?); `validate`; `upload` with progress/error UI.
- **Test**: ✅ selftest harness (parse→emit→round-trip→CLI validate PASS), ✅ self-contained bundle (PASS under empty $HOME), ✅ IOKit detect vs real pad (`DETECTED 1189:8890`), ✅ GUI launch stable. ⏳ real pad flash via app — awaiting user go-ahead (destructive).

### M2 — Pad editor GUI  `(2–3 days)`
- Visual 3×2 + knob layout; click a button/knob-slot to assign an action; layer tabs (3); action picker covering the full `doc/actions.md` vocabulary (keys, modifiers, sequences, mouse, media, timed); orientation setting; live YAML preview.
- **Test**: build config entirely by clicking → validate → upload → physical pad matches. Commit.

### M3 — Live test panel  `(1–2 days)` 🔶 code+autotests DONE; hw test blocked on USB recovery
- IOHIDManager listener for 1189:8890; pad graphic highlights presses; knob shows CW/CCW rotation + press; event log with timestamps; start/stop toggle.
- **Test**: press/turn every control on the real pad, verify each is detected and mapped to the right slot. Commit.
- Implemented: `LiveEventMonitor` (keys page 0x07/0x04, consumer 0x0C, wheel 0x01/0x38+0x48, mouse buttons 0x02→knob press), slot highlighting via `normalizeAction` + `mouseButton(for:)` matching, `LiveTestPanelView` toggle + timestamped log. Needs Input Monitoring TCC permission at runtime (prompts). ⏳ hw test blocked: macOS USB stack wedged (see pickupandgo) — pad must be physically re-plugged first.

### M4 — Config library (save/manage)  `(1 day)`
- Named configs stored under Application Support; create/duplicate/rename/delete; one-click apply (→ M1 upload path); active-config indicator.
- **Test**: create 3 configs, switch between them, flash each. Commit.

### M5 — Import / export  `(0.5–1 day)`
- Export current/selected config to `.yaml`; import from file with schema validation and clear error reporting; drag & drop onto window.
- **Test**: export → wipe → re-import round-trip byte-identical; importing the upstream `example-mapping.yaml` works. Commit.

### M6 — Packaging & polish  `(1 day)`
- Standalone .app bundle (versioned, icon, bundle id), codesign (adhoc at minimum), README with usage, final E2E pass.
- **Test**: run the built .app from a clean launch (no Xcode), full flow: detect → edit → test → save → export → upload. Commit.

**Total estimate: ~7–10 working days of agent time, pad must stay USB-connected for hardware tests in M1/M2/M3/M6.**

## Risks / notes
- `upload` is destructive & irreversible on-device → the app always commits snapshots of configs (M4) and warns before flashing.
- IOHIDManager report parsing (M3) is the least-spec'd part; keyboard reports are standard HID usages, knob rotation on these pads arrives via consumer/mouse wheel usages — will verify against the real device early in M3.
- macOS may eventually need no special entitlements (no sandbox for a directly-launched app); App Store distribution would need sandbox + USB entitlement — out of scope unless requested.
