# pickupandgo.md — Handoff Log

> Purpose: any AI model can resume this project from this file alone.
> Newest entry at the top. Keep updated after every meaningful step.

## STATE 2026-10-10 (late) — 🧭 MENU BAR HELPER + 🖨 PRINTABLE LABELS

- **MicroPad Menu.app** (target `MicroPadMenu`, LSUIElement, bundle `com.micropadstudio.menu`): MenuBarExtra
  `.menu` style; shares `MicroPadStudio/Model` + 4 Services files. Templates + saved configs as submenus
  (Flash to Pad + numbered cheat sheet); ✓ = matches `PadState` digest; icon spins while flashing;
  NSAlert confirm with "Don't ask again"; Open Studio; Launch at Login (SMAppService).
  `MenuSelftest` (needs MICROPAD_SUPPORT_DIR + MICROPAD_TOOL_PATH=fake tool) PASS. Menu verified via
  System Events (`menu bar item 1 of menu bar 2` of process "MicroPad Menu"). Real hardware flash via the
  helper NOT yet done (same `Ch57xTool.upload` as Studio, which is hardware-verified).
- `PadState` (`Application Support/MicroPadStudio/pad-state.json`) written by both apps after upload.
- `Ch57xTool.upload`: flock on `upload.lock` → `.busy`; timeout 120 s. Test env overrides:
  `MICROPAD_TOOL_PATH`, `MICROPAD_SUPPORT_DIR`.
- **Labels PDF**: `LabelSheetView` (true mm, Letter) + `LabelSheetPDF.write` (ImageRenderer → CGContext PDF);
  button "Print Labels (PDF)…" in the guide footer → NSSavePanel → opens in Preview. Selftest renders all
  templates (1 page, Letter mediabox). Inspect: `MPS_KEEP_PDF=1 … --selftest mapping.yaml` then
  `sips -s format png file.pdf --out x.png`. Keycap sticker size = `LabelSheetView.keycapMM` (15 mm).
- `package_dist.sh` builds/signs both apps; zip contains both.

## STATE 2026-10-10 — 📋 TEMPLATE GUIDE + CONTROL NOTES + APP ICON

- **Templates** toolbar button (Re-scan became an icon to fit 980pt) → `TemplateGuideView` sheet (900×620):
  sidebar = Built-in Templates (`Resources/templates/*.yaml`, from repo `templates/` folder ref) /
  Saved Configs (library) / Current editor; detail = `PadDiagramView` (rainbow keycaps like the icon,
  numbered badges, knob with ↻/press/↺) + numbered listing (position, keys, function, explanation).
  Footer: Load into Editor (template or saved) / Save to Library (template).
- **Notes format** (`MappingYAML.emitDocs/parseDocs`): `# @title`, `# @summary`, `# @note <key> <label> | <detail>`;
  keys from `PadMapping.noteKey` (`b1-1`, `knob-press`, `L2.` prefix). CLI ignores comments (selftest proves it).
  Persist through library save/dup/rename/export because they all go emit→parse.
- `ActionDescriber` → "Ctrl + C" / "Copy (Windows/Linux)" fallbacks when a control has no note.
- Editor tiles + knob segments show the note label; inspector has Function / Explanation fields.
- App icon from `design/icon-source.png` via `design/make_icon.py` (asset catalog `AppIcon`).
- Tests: selftest += notes round-trip + CLI validate, describer cases, every bundled template has
  @title/@note and validates; `--layout-test --guide` hosts the sheet. All PASS. GUI checked via
  screenshots (guide: template / saved / editor views; load-into-editor; inspector note fields).
- Templates shipped (12): Total Annihilation (Windows); macOS: VS Code, Git (Terminal, oh-my-zsh aliases), iTerm2,
  Chrome, Notion, iMovie, Zoom, GIMP, Claude Code, Evernote, Meta Muse. Shortcuts are app defaults from memory —
  not verified in each app. Meta Muse: no published shortcuts (searched 2026-10-10); New chat/Stop marked UNVERIFIED.
  Evernote Search/Sync = classic defaults, flagged in notes.
- ⚠️ **Firmware limit: ≤5 accords per sequence** (upstream doc/actions.md). `ch57x-keyboard-tool validate`
  does NOT enforce it (accepted 200). App enforces via `MappingLint` in Validate + Upload; selftest checks templates.
- Library copy "Total Annihilation" replaced with the annotated template. Pad NOT reflashed
  (still single-layer a s d / z x c, knob ←/enter/→).

## STATE 2026-10-10 (signing) — 🔏 STABLE SIGNING IDENTITY — dist signed; TCC re-grant pending once

- `scripts/setup_signing.sh` (run once, idempotent): self-signed codeSigning cert
  "MicroPad Studio Local Signing" (SHA-1 `D6521C31C4BEAF9F7451244447ACA77F0DA770AE`, 10 y) in dedicated
  keychain `~/Library/Keychains/micropad-signing.keychain-db` (added to user search list; no
  auto-lock; partition list set so codesign never prompts). Password: `~/.config/micropad-studio/signing-keychain-password`.
  `find-identity` shows it as CSSMERR_TP_NOT_TRUSTED — expected and fine for codesign/TCC.
- `scripts/package_dist.sh` [`SKIP_BUILD=1`]: build Release → ditto to dist → sign bundled CLI then
  app with the identity → verify → zip. Designated requirement:
  `identifier "com.micropadstudio.app" and certificate leaf = H"d6521c31…"` — build-independent.
- **Never re-sign dist ad-hoc** (would drop the TCC grant again).

✅ **VERIFIED:** user re-granted Input Monitoring once; then two rebuilds with different CDHashes
(7ad4cba8… → 82aadbb9… [build 999] → 2969e958… [v1.0 build 1]) all got "monitor started (pad connected)"
with no re-grant — the grant survives rebuilds.
- `project.yml` now sets `MARKETING_VERSION 1.0` / `CURRENT_PROJECT_VERSION 1` (Info.plist previously
  had NO CFBundleVersion). Bump these for releases.
- Commit hygiene: stage files explicitly — `git add -A` swept an untracked helper
  (`scripts/ax_clicktest.sh`, AX click test from an earlier session) into `c93eaf3`.

### NEXT
1. Button/knob press test with Live Test (human at the pad).

## STATE 2026-10-10 (late night) — ✅ PAD REFLASHED: SINGLE LAYER (no layer-switch button exists)

**Hardware fact (user-confirmed): this pad has NO side/layer button** → layers 2+ are unreachable.
- `mapping.yaml` → 1 layer: buttons `a s d` / `z x c`, knob ccw `left` / press `enter` / cw `right`
  (user's choice). Committed `be6a7c1`, then flashed via CLI: exit 0 in 75 s. Pad == `mapping.yaml`.
- App: layer picker hidden when `layers.count == 1`; `defaultMapping` is single-layer.
- dist rebuilt (`ditto` copy of Release build → `codesign --force --deep -s -` → `ditto -c -k` zip).

**TCC gotcha:** Input Monitoring for an ad-hoc app is bound to that exact binary (cdhash). Every
rebuild of `dist/MicroPadStudio.app` loses the grant → user must remove + re-add (or toggle) it in
System Settings → Privacy & Security → Input Monitoring. Verified: old dist got "monitor started",
new dist reports no permission. A stable signing identity would fix this permanently.

### REMAINING (human-only)
1. Re-grant Input Monitoring for the rebuilt dist app, toggle Live Test, press 6 buttons + knob.

## STATE 2026-10-10 (night) — ✅ APP E2E VERIFIED ON REAL PAD (upload via GUI) — only human-only checks remain

Docs fixed: MILESTONES statuses current, README (bundled CLI, not PATH; repo layout; layout-test),
stale SPM M0 entry marked superseded, this file's header moved to top. **Yams pinned
`exactVersion: 6.2.2`** in `project.yml` (Package.resolved is gitignored).

Verified on a clean Release build (pinned Yams):
- `--selftest mapping.yaml` PASS (also under empty `$HOME` → bundle self-contained);
  `--layout-test` and `--layout-test --select-key` both PASS.
- Real GUI driven by synthetic CGEvent clicks (terminal HAS Accessibility now: `AXIsProcessTrusted()==true`;
  `screencapture -R` works while display awake): device dot green "Micropad connected (8890)";
  selecting key 1-2 keeps the grid fully visible (compact Category menu); Validate → "✅ Config is valid.";
  **Upload → confirm dialog → ⏳ (UI responsive, buttons disabled) → "✅ Uploaded to pad."**
  Pad content unchanged (same committed `mapping.yaml`).
- Live Test toggle → shows "grant Input Monitoring" guidance (TCC not granted; user action).

Learned:
- **Launch the GUI with `open -n <app>`** for window checks. Exec'ing the binary directly from a
  subprocess creates no main window (only menu-bar strips) — not an app bug.
- Upload took **~60–65 s**: libusb `darwin_init → darwin_get_cached_device` blocks (proc state `U`)
  while enumerating the bus, then proceeds. 90 s timeout is just enough; consider raising to ~150 s
  if a slow-enumeration upload ever times out. `system_profiler SPUSBDataType` returns 0 lines on this
  box even when healthy — not a wedge indicator by itself.
- Helper click/window tools used: CGEvent mouse post + PID-filtered `CGWindowListCopyWindowInfo`.

### REMAINING (human-only)
1. Grant Input Monitoring to MicroPadStudio, toggle Live Test, press 6 buttons + knob → highlights match.
2. Physical feel check of layer 1 (a s d / z x c + wheel) and layer switch.

## STATE 2026-10-10 (evening) — ✅ FIRST FLASH SUCCEEDED — pad now runs repo mapping.yaml

`ch57x-keyboard-tool upload < mapping.yaml` → **exit 0**, post-flash HID probe fast/responsive
(no wedge). Pad state == `mapping.yaml` @ `a2e39b6` (committed unchanged — git history is the
backup; no read-back exists). Validate passed immediately before upload (`config is valid 👌`).
Note: macOS has no `timeout` binary — wrap CLI calls with `python3 subprocess.run(timeout=)`
(the terminal harness also rejects shell `&` backgrounding in foreground commands).

### REMAINING
1. User eyes-on GUI: `dist/MicroPadStudio.app` (19:59 build, layout-test clean both states) —
   click keys at min window size: grid must stay visible; Validate/Upload show ⏳ without freezing.
2. Hardware feel: press the 6 buttons / knob (see newest entry for current mapping).
   ~~Layer switch via side button~~ — pad has no layer button.
3. App Live Test panel: toggle it, grant Input Monitoring (adhoc app is targeted by path; if
   no events, System Settings → Privacy → Input Monitoring). Highlights must match presses.

## STATE 2026-10-10 — 🐛 USER-REPORTED BUGS FIXED (UI clipping + upload freeze) — dist rebuilt, needs eyes-on + hardware test

User tested the M6 dist build and found two real bugs. Both fixed, with a headless
regression test that proves the fix:

1. **Pad grid pushed off-screen when a key is selected** ("shows 2x2, mapping.yml
   pushed keys out of frame"). Root cause (measured, not guessed): the Action
   inspector's 5-segment **segmented Category picker is non-shrinkable (~405pt)**
   and appears only when a key is selected, raising the HStack min width from
   ~978 to >980 → whole layout overflows, grid clips off the left edge.
   - Fix: `ViewThatFits` in `ActionInspectorView` (segmented only when it fits,
     compact `.menu` picker otherwise) + `lineLimit`/truncation on the header rows
     + `fixedSize(horizontal:false)` on the help caption.
2. **Validate/Upload froze the UI** (upload could hang forever with a wedged pad).
   - Fix: `Ch57xTool` is now a stateless struct with hard timeouts (validate/show-keys
     15s, upload 90s; SIGTERM→SIGKILL escalation, actionable "replug the pad" message);
     `MappingStore.validate()/upload()` run on `Task.detached` and hop back to MainActor.
     `upload()` now also stops the Live Test monitor first (our IOHIDManager listen can
     stall the vendor write).

**New headless test**: `MicroPadStudio --layout-test [--select-key]` — hosts the real
ContentView in an offscreen NSHostingView at 980×540, walks the NSView tree, fails if
any view frame leaves the window. Verified: old code FAILS with `--select-key`
(widest offender: `SystemSegmentedControl` at x=613…1018 > 980); fixed code PASSES
both states. Keep this pattern for future layout regressions.

Diagnostics learned the hard way:
- `osascript … count of windows` can report **0** for the app while the display sleeps
  / on the secondary display, even though `CGWindowListCopyWindowInfo` shows the
  windows with real bounds. Use `scripts/winlist.swift`-style CG queries for truth.
- Selftest flag is `--selftest <yaml>` (the `MICROPADSTUDIO_*` env var is only a
  launched-marker; running the binary without the flag just starts the GUI).
- `screencapture -R` fails ("could not create image from rect") while displays are
  asleep — wake the display before visual verification.

Dist rebuilt (adhoc-signed, arm64): `dist/MicroPadStudio.app` + `.zip`; release binary
passes `--selftest` and both `--layout-test` states.

### NEXT (in order)
1. User eyes-on: open `dist/MicroPadStudio.app`, click keys at min window size —
   grid must stay fully visible; Validate should show ⏳ without freezing.
2. Hardware (still untested on real pad): Live Test panel highlight, then FIRST
   upload of `mapping.yaml` (commit any mapping change before uploading!).
3. If pad firmware rejects ch57x-2/2x3 shape → adjust mapping.yaml, re-validate, upload.




---

## STATE 2026-10-09 (later) — M0 DONE ✅ (build/launch/window verified) — M1 underway

> ⚠️ SUPERSEDED: this entry describes the parallel SPM scaffold (`MicroPadCore`,
> `Scripts/build_app.sh`) that was **removed** in `8392340`. The live layout is the
> XcodeGen one (`project.yml` → `MicroPadStudio/`). Kept for history only.

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
