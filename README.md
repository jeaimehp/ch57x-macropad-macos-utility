# ch57xx-micropad

Key-mapping project for a **3×2 + 1 knob CH57x macro pad** (USB `1189:8890`),
programmed with
[ch57x-keyboard-tool](https://github.com/kriomant/ch57x-keyboard-tool) (v1.7.0,
installed at `~/.local/bin/ch57x-keyboard-tool`).

## Layout of this repo

| File | Purpose |
|---|---|
| `mapping.yaml` | Active key-mapping config (2×3 buttons + 1 knob, 1 layer — the pad has no layer-switch button) — currently flashed on the pad |
| `MicroPadStudio/` | SwiftUI app source (Model / Services / Views) |
| `project.yml` | XcodeGen spec (`xcodegen generate` → `.xcodeproj`, gitignored) |
| `templates/` | Built-in templates bundled into the app (e.g. `total-annihilation.yaml`); also usable with `upload <` directly |
| `vendor/` | Bundled `ch57x-keyboard-tool` v1.7.0 universal binary (MIT) |
| `scripts/` | GUI-verification helpers (CG window list, displays, AX dump) |
| `MILESTONES.md` / `pickupandgo.md` | Plan + handoff log |

## Workflow

```bash
# 1. Edit mapping.yaml, then validate (config goes via stdin!)
ch57x-keyboard-tool validate < mapping.yaml

# 2. Upload to the pad (USB cable required — THIS OVERWRITES the pad, no read-back)
ch57x-keyboard-tool upload < mapping.yaml

# 3. Commit so you can always re-flash any previous version
git add mapping.yaml && git commit -m "layer 2: zoom knob"
```

Since the tool cannot read mappings back off the device, **git history is the
only backup** — commit after every successful upload.

## Gotchas

- Key name is `escape`, not `esc` (`show-keys` lists all names).
- Actions reference: [`doc/actions.md`](https://github.com/kriomant/ch57x-keyboard-tool/blob/master/doc/actions.md).
- Rotated numbering? Fix `orientation:` rather than rearranging button arrays.
- Rows/columns are counted with the knob(s) on the right.

## MicroPadStudio.app (M0–M6)

Native macOS GUI around `ch57x-keyboard-tool`: visual pad editor (layer tabs appear only for multi-layer configs),
validate/upload, named config library, import/export + drag&drop YAML, live
test panel (buttons/knob/mouse via IOHIDManager).

- Build: `xcodegen generate && xcodebuild -project MicroPadStudio.xcodeproj -scheme MicroPadStudio -configuration Release -derivedDataPath ./DerivedData build`
- Package: `scripts/package_dist.sh` → `dist/MicroPadStudio.app` + `dist/MicroPadStudio.zip`,
  signed with the stable local identity "MicroPad Studio Local Signing" (one-time setup:
  `scripts/setup_signing.sh` — self-signed cert in its own keychain
  `~/Library/Keychains/micropad-signing.keychain-db`, password in
  `~/.config/micropad-studio/`). Stable signature ⇒ Input Monitoring grant survives rebuilds.
  Not Apple-issued: other Macs still see an unidentified developer.
- **Templates** button: guide sheet listing built-in templates, saved configs and the
  current editor — each with a pictorial pad (functions printed on the keys/knob) and a
  numbered listing explaining every control. Load into editor / save to library.
- **Print Labels (PDF)…** (Templates guide footer): one Letter page per config — true-size
  keycap stickers (15 mm, two sets), knob tags, a desk card and a reference table, with a
  50 mm scale bar. Print at 100 %.
- **MicroPad Menu.app** (menu bar helper, no Dock icon): every template + saved config as a
  submenu with *Flash to Pad* and a control cheat sheet; ✓ marks what's on the pad
  (shared `pad-state.json`); uploads are flock-serialised with Studio. Launch at Login toggle.
- Control notes live in the YAML as comments the CLI ignores:
  `# @title …`, `# @summary …`, `# @note b1-1 Label | Explanation` (keys `b<row>-<col>`,
  `knob-ccw|press|cw`; `L2.` prefix for later layers). Edit them per key in the inspector;
  unannotated configs get generated explanations.
- Headless tests: `MicroPadStudio.app/Contents/MacOS/MicroPadStudio --selftest mapping.yaml`
- Self-contained: the app bundles `ch57x-keyboard-tool` (from `vendor/`) in
  `Contents/Resources` and falls back to `~/.local/bin/ch57x-keyboard-tool`.
  PATH is not searched.
- Layout regression test: `MicroPadStudio.app/Contents/MacOS/MicroPadStudio --layout-test [--select-key | --guide]`
- Yams is pinned to an exact version in `project.yml` (the generated
  `Package.resolved` is gitignored).

- Always package via `scripts/package_dist.sh`: an ad-hoc re-sign would change the signature and drop the Input Monitoring grant.
