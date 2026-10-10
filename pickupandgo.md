# pickupandgo.md — Handoff Log

> Purpose: any AI model can resume this project from this file alone.
> Newest entry at the top. Keep updated after every meaningful step.

---

## STATE 2026-10-09 (later) — M0 DONE ✅ (build/launch/window verified) — M1 underway

**Plan approved by user ("approve — keep working until all milestones implemented").**

### M0 results
- SPM package (swift-tools 6.0, lang mode v5, macOS 14+): targets `MicroPadCore` (lib),
  `MicroPadStudio` (exec), `MicroPadCoreTests`.
- `Scripts/build_app.sh` → assembles `dist/MicroPadStudio.app` (Info.plist from
  `Resources/`, copies `~/.local/bin/ch57x-keyboard-tool` into `Contents/Resources/`,
  adhoc codesign). `--debug` flag available.
- Verified: `swift build -c release` OK (Swift 6.4), `swift test` green, app launches
  (PID confirmed), System Events reports window "MicroPad Studio".
- **Test-harness note for later milestones:** `screencapture` FAILS (terminal lacks screen
  recording permission). Verify GUI liveness via
  `osascript -e 'tell application "System Events" to get name of every window of process "MicroPadStudio"'`
  and `pgrep -lf MicroPadStudio`.

### NEXT STEP
**M1**: MicroPadCore — PadMapping model + YAML read/write (hand-rolled parser for the
upstream format; no external deps) + CLI wrapper (Process running bundled
`ch57x-keyboard-tool` via stdin) + device detection (ioreg vendor 4489). Unit tests:
parse repo `mapping.yaml` round-trip; validate via real CLI. Final M1 acceptance: flash
test on the real pad (user pre-approved; baseline config committed in a2e39b6).

---

## STATE 2026-10-09 (latest) — M3 code DONE ✅ · 🔴 USB STACK WEDGED: user must re-plug the pad → NEXT: flash pad, M3 hw test, M4

### 🔴 BLOCKER (hardware, needs hands)
- macOS USB reporting/enumeration is wedged: `system_profiler SPUSBDataType` returns 0 lines;
  `ch57x-keyboard-tool upload` hangs inside libusb `darwin_get_cached_device` (bus enumeration blocks
  on an unresponsive device). ioreg still shows the pad (cached). No non-root software fix.
- Probable cause: three zombied `xctest` procs from `~/micropad-studio/` (separate side project!)
  stuck in `DevicePresenceTests` held the pad's HID connection since ~14:28; first upload attempt hit
  60s timeout mid-negotiation. **FIX: unplug/replug the pad (or power-cycle hub/dock).**
- Pad has NEVER been successfully flashed (repo mapping.yaml is still the intended first flash).
- Consent note: user approved plan incl. hw tests and said "keep working until all milestones done"
  → flash consented; blocked only by the above.

### M3 implemented (build ✅ selftest PASS ✅ GUI stable ✅ · hw test pending USB recovery)
- `Services/LiveEventMonitor.swift`: IOHIDManager matching 1189:8890; callbacks on main runloop;
  usage decoding: keys (0x07/0x04→key names incl a-z/digits/F/home/arrows), consumer (0x0C media),
  wheel (0x01 usage 0x38 wheel / 0x48 h-wheel → signed delta), mouse buttons (0x02 → knob press).
  `IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)` — needs Input Monitoring TCC on first run.
- `MappingStore`: live wiring (`pressedKeyName` `_mouseN` sentinel for clicks), `wheelDir` w/ 0.4s
  auto-clear, `normalizeAction` (strips `{delay}`/mods/comma-sequences), `mouseButton(for:)` click→1/2/3,
  `isSlotPressed(slot)` highlights editor slots orange; `LiveTestPanelView` (toggle + timestamped log).
- Selftest: +normalize(7) +mouseButton(7) cases — caught an off-by-one dropFirst(5→6).
- Swift gotchas: `IOHIDValueGetValue` doesn't exist → `IOHIDValueGetIntegerValue` (returns CFIndex;
  cast Int32 for wheel); foreground shell rejects `&` → use background process mechanism for GUI tests.

### NEXT (in order)
1. After pad re-plug: verify `system_profiler SPUSBDataType` non-empty → `~/.local/bin/ch57x-keyboard-tool upload < mapping.yaml`
   (repo dir; then commit that mapping unchanged — it IS the pad's state, no read-back exists).
2. M3 hw test: enable Live Test in app (grant Input Monitoring when prompted), press all 6 buttons
   + turn/press knob, verify orange highlights match slots. ⚠️ TCC: app is adhoc/unsigned — prompt
   targets it by path; if events don't flow, check System Settings → Privacy → Input Monitoring.
3. M4 config library, M5 import/export, M6 packaging (pure software until E2E).

## STATE 2026-10-09 — M2 COMPLETE ✅ → NEXT: M3 live-test panel

M2 shipped: visual pad editor + action picker.
- `Model/ActionsCatalog.swift` — action vocabulary from `show-keys` v1.7.0 + doc/actions.md
  (5 tabs: Common/Keys/Media/Mouse/Advanced). Verified: `""` and `none` are NOT valid no-ops
  upstream → picker offers no "clear"; user must pick a real action.
- `Views/PadEditorView.swift` — segmented layer tabs (1..N), 2×3 grid, knob as 3 segments
  (CW / Press / CCW); selected slot highlighted with accent border.
- `Views/ActionInspectorView.swift` — category picker + filter field + adaptive button grid +
  raw custom-action field (combos/sequences/mouse). `.id(selection)` resets filter per slot.
- `MappingStore` — `Slot` enum (button(r,c)/knobCCW/Press/CW), `currentLayer`, `selection`,
  `action(for:)`/`assign(_:to:)` (all writes flow through YAML re-emit → CLI validate).
- Selftest extended: model edit round-trip + CLI validate of edited YAML → `SELFTEST PASS`.
Verified: BUILD SUCCEEDED; selftest PASS; GUI launches stable (RSS ~107MB, no crash).
Gotcha: Swift dictionary literals are unordered — never build display-order arrays from `[k:v]`.

⏳ Carry-over: flash-the-pad hardware test still needs explicit user consent (M1 item,
also gates final M6 E2E).

## STATE 2026-10-09 — M1 COMPLETE ✅ (code+tests)

M1 shipped: YAML model + Yams parser (typed errors), `MappingYAML` deterministic emitter,
`Ch57xTool` (bundled binary in `Contents/Resources`, fallback `~/.local/bin`; validate/upload via stdin),
`DeviceMonitor` (IOKit poll; verified live: `DETECTED 1189:8890`), `MappingStore` + minimal UI
(device dot, Validate, Upload w/ confirm, YAML preview, result log), `--selftest <yaml>` harness.
Verified: selftest PASS; PASS under empty `$HOME` (proves self-contained bundle); GUI stable >10s.
Gotchas fixed: xcodegen silently ignores target `resources:` key — use `sources: [{path, buildPhase: resources}]`;
`CFDictionarySetValue` needs `Unmanaged.passUnretained(...).toOpaque()` for keys/values.
⏳ ONLY M1 test left: flash the pad through the app — destructive, awaiting explicit user go-ahead.

## STATE 2026-10-09 (earlier) — M0 COMPLETE ✅

Plan approved by user ("approve"). M0 scaffold done:
- `project.yml` (XcodeGen) → `MicroPadStudio.xcodeproj` (gitignored, always regenerate with `xcodegen generate`).
- `MicroPadStudio/MicroPadStudioApp.swift` + `ContentView.swift`: 2-pane placeholder window,
  prints `MICROPADSTUDIO_LAUNCHED pid=N` to stdout as headless launch proof.
- Build: `xcodegen generate && xcodebuild -project MicroPadStudio.xcodeproj -scheme MicroPadStudio
  -configuration Debug -derivedDataPath ./DerivedData build` → **BUILD SUCCEEDED**.
- Launch test: app ran >4s with live run loop (PID verified), killed after. Window content not
  screenshot-able headless (osascript lacks Accessibility) — user can visually confirm.

### XcodeGen pitfalls (this box: xcodegen 2.46 + Xcode 27) — do not rediscover
- Target `info:` block fails with opaque `Decoding failed at "path"` → **don't use it**;
  use `GENERATE_INFOPLIST_FILE: YES` in settings instead.
- `PRODUCT_NAME`/`PRODUCT_MODULE_NAME` come out EMPTY → `Module name "" is not a valid identifier`.
  Must set `PRODUCT_NAME: "$(TARGET_NAME)"` explicitly in target settings.
- Terminal harness rejects `cmd &` — background GUI apps via the background-process mechanism,
  and `osascript` window queries need Accessibility (not granted; don't rely on them).

### NEXT STEP: M1 — Core plumbing (from MILESTONES.md)
Swift YAML mapping model (Codable), bundle `ch57x-keyboard-tool` binary as
resources/build phase, device detection, validate + upload via `Process` (stdin!),
error/progress UI. Test on the real pad (USB-cabled), then commit + update this file.
Pad config ground truth: `mapping.yaml` in repo root (validated; never uploaded yet —
flashing still requires user confirmation).

---

## STATE 2026-10-09 — PLAN READY, WAITING FOR USER APPROVAL (no app code yet)

### What this project is
Build **MicroPad Studio**, a macOS SwiftUI GUI app to configure a 3×2 + 1 knob
CH57x micropad (USB `1189:8890`), based on
https://github.com/kriomant/ch57x-keyboard-tool. Requirements (user's words):
1. GUI to set functions of the 6 buttons + 1 knob
2. GUI mirror of the pad that live-tests presses/knob turns
3. Save multiple named configurations
4. Import/export configurations
5. Milestones first, **wait for approval before coding**
6. Test each implementation before moving forward
7. Git commits with notes (this repo: `~/ch57xx-micropad`)
8. Keep `pickupandgo.md` updated (this file)

### Environment facts (verified this session)
- macOS 26.6.2, arm64, **Xcode 27.0** at /Applications/Xcode.app, Swift 6.4, git 2.54.
- `ch57x-keyboard-tool` v1.7.0 installed: `~/.local/bin/ch57x-keyboard-tool`.
  Commands: `show-keys | validate | upload | led` — **config goes via STDIN** (`validate < f.yaml`).
  No `download`/read-back — flashing is irreversible → git history is the only backup.
- Pad detected on USB via `ioreg -p IOUSB -l -w0 | grep '"idVendor" = 4489'` (4489=0x1189);
  enumerates under a hub as generic "HID Device". `system_profiler SPUSBDataType` may return empty here.
- Working validated pad config: `mapping.yaml` in this repo (`model: ch57x-2`, rows 2, cols 3, knobs 1,
  3 layers). Validated OK but **NOT yet uploaded to the device**.
- Hermes skill `ch57x-micropad` exists with the CLI workflow + pitfalls (`escape` not `esc`, etc.).

### Decisions made
- Native SwiftUI app; bundle the existing Rust CLI binary inside the .app for validate/upload
  (Process + stdin); IOHIDManager for the live-test panel; YAML = same format as upstream tool.
  Full rationale + milestone breakdown M0–M6: **`MILESTONES.md`**.

### Done
- [x] CLI installed (v1.7.0), device detected, `mapping.yaml` validated
- [x] Repo `~/ch57xx-micropad` (branch `main`): initial commit + this plan
- [x] `MILESTONES.md` written (status: pending approval)

### NEXT STEP for whoever picks this up
1. If user has **approved** `MILESTONES.md` → start **M0** (Xcode scaffold, .gitignore,
   app builds & launches, commit). Do not skip hardware tests in M1/M2/M3/M6 — pad is on the desk, USB-connected.
2. If **not yet approved** → wait / discuss plan adjustments; only edit `MILESTONES.md`, no app code.
3. Update this file + commit with notes after every step.

### Known gotchas (do not rediscover these)
- `upload` overwrites the pad with no read-back — always confirm, always commit config first.
- v1.7.0 CLI: stdin-only config; no `list-keyboards`; key name `escape` not `esc`.
- Pad must be USB-cabled (not BT) to program. Rows/cols counted with knob on the right.
- Hermes `patch` tool can't touch `~/.hermes/config.yaml`; irrelevant to app but needed if tweaking agent config.
