# ch57xx-micropad

Key-mapping project for a **3×2 + 1 knob CH57x macro pad** (USB `1189:8890`),
programmed with
[ch57x-keyboard-tool](https://github.com/kriomant/ch57x-keyboard-tool) (v1.7.0,
installed at `~/.local/bin/ch57x-keyboard-tool`).

## Layout of this repo

| File | Purpose |
|---|---|
| `mapping.yaml` | Active key-mapping config (2×3 buttons + 1 knob, 3 layers) — currently flashed on the pad |
| `MicroPadStudio/` | SwiftUI app source (Model / Services / Views) |
| `project.yml` | XcodeGen spec (`xcodegen generate` → `.xcodeproj`, gitignored) |
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

Native macOS GUI around `ch57x-keyboard-tool`: visual 3-layer pad editor,
validate/upload, named config library, import/export + drag&drop YAML, live
test panel (buttons/knob/mouse via IOHIDManager).

- Build: `xcodegen generate && xcodebuild -project MicroPadStudio.xcodeproj -scheme MicroPadStudio -configuration Release -derivedDataPath ./DerivedData build`
- Package: `dist/MicroPadStudio.app` + `dist/MicroPadStudio.zip` (adhoc-signed)
- Headless tests: `MicroPadStudio.app/Contents/MacOS/MicroPadStudio --selftest mapping.yaml`
- Self-contained: the app bundles `ch57x-keyboard-tool` (from `vendor/`) in
  `Contents/Resources` and falls back to `~/.local/bin/ch57x-keyboard-tool`.
  PATH is not searched.
- Layout regression test: `MicroPadStudio.app/Contents/MacOS/MicroPadStudio --layout-test [--select-key]`
- Yams is pinned to an exact version in `project.yml` (the generated
  `Package.resolved` is gitignored).
