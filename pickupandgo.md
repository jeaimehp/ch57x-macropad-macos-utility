# pickupandgo.md — Handoff Log

> Purpose: any AI model can resume this project from this file alone.
> Newest entry at the top. Keep updated after every meaningful step.

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
