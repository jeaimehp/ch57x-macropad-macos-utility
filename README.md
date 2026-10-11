# ch57xx-micropad — MicroPad Studio

Mac tools for a **3×2 + 1 knob CH57x macro pad** (USB `1189:8890`, standard MX
keycaps, no layer button). Built around
[ch57x-keyboard-tool](https://github.com/kriomant/ch57x-keyboard-tool) v1.7.0,
which is bundled — nothing else to install.

Two apps:

| App | What it's for |
|---|---|
| **MicroPad Studio** | Edit what each key and the knob do, browse templates, save/import/export configs, flash the pad, live-test key presses, print labels. |
| **MicroPad Menu** | Menu bar helper: flash any template or saved config in two clicks, and power the *Open app* / *Dictate* keys. |

## Quick start

1. Open `dist/MicroPadStudio.app` (and `dist/MicroPad Menu.app` for the menu bar helper).
2. **Templates** → pick one → **Load into Editor** → **Upload to Pad…** (≈1 minute, don't unplug).
   Or from the menu bar: MicroPad Menu → *template* → **Flash to Pad**.
3. Optional: **Print Labels (PDF)** in the Templates window for keycap stickers or a faceplate.

The pad has no read-back: whatever you flash replaces what's on it. Templates and saved
configs are kept, so you can always flash them again.

## Features

### MicroPad Studio — the editor

![MicroPad Studio editor with the Zoom template loaded](docs/screenshots/studio-editor.png)

- **Status bar** — green dot when the pad is plugged in; the config name (or *Unsaved*) opens the
  **config library** (save / save as / duplicate / rename / delete).
- **Toolbar** — **Templates** guide, ↻ re-scan for the pad, **Import… / Export…** `.yaml`
  (you can also drag a `.yaml` onto the window), **Validate**, **Upload to Pad…**.
- **Editor** — the pad as rainbow keycaps (same colours as the icon, guide and printed labels) plus
  the knob's three actions: turn right, press, turn left. Each key shows its function name and
  keystroke. Click one to edit it.
- **Live Test** — press keys or turn the knob and the matching control lights up (needs
  Input Monitoring once).
- **mapping.yaml** — live preview of exactly what will be sent to the pad.
- Bottom line — result of the last action (validated, uploaded, saved, errors).

![Editing a key: action picker and notes](docs/screenshots/studio-inspector.png)

- **Action inspector** (after clicking a control) — pick from *Common* (copy, paste, Spotlight…),
  *Keys*, *Media*, *Mouse* or *Advanced*, filter by name, or type a custom action: combos (`ctrl-c`),
  sequences of up to 5 keys (`g,s,t,enter`), mouse (`click`, `wheel(-5)`) or raw codes (`<72>`).
- **Function / Explanation** fields — name the control and describe it; shown on the keycap, in
  the guide and on printed labels.
- **Validate** and **Upload** refuse things the pad can't play (see *Pad limits*). Upload asks for
  confirmation, takes about a minute and keeps the window responsive.

### Templates guide

![Templates guide showing the Meta Muse template](docs/screenshots/templates-guide.png)

- Sidebar: **Built-in Templates**, your **Saved Configs** and the **Current editor**.
- Each entry shows a picture of the pad with every function on its key, the knob actions, and a
  numbered list: position, keystroke, function and a plain-English explanation (generated
  automatically when a config has no notes).
- **Load into Editor**, **Save to Library**, and **Print Labels (PDF)**. Loading only changes the
  editor; use **Upload to Pad** to flash it.

### Printable labels

| Keycap stickers, knob legend & desk card | Faceplate overlay & tape-on strips |
|---|---|
| ![Sticker sheet](docs/screenshots/labels-stickers.png) | ![Faceplate sheet](docs/screenshots/labels-faceplate.png) |

True-size US Letter PDFs (print at **100 % / Actual Size**; check the 50 mm scale bar):
- **Keycap stickers** — 12 mm, fit standard MX keycap tops; two sets, in each key's colour.
- **Knob legend** — 17×20 mm, sits on the plate below the knob.
- **Desk card** and **reference table** — keep beside the pad.
- **Faceplate overlay** — pad-shaped card with one window around all six keys and a hole for the
  knob; labels print above and below the keys. Cut it out and lay it over the pad.
- **Tape-on strips** — the same labels as two thin strips to tape above and below the keys.

Sizes come from a ruler photo of the pad (`PadGeometry` in `FaceplateSheetView.swift`).

### MicroPad Menu — menu bar helper

![MicroPad Menu](docs/screenshots/menu-bar-helper.png)

- **Status** — pad connected, **what's on the pad** (✓ in the list) and when it was flashed,
  active app keys, and the result of the last flash.
- **Templates / Saved Configs** — each is a submenu with **Flash to Pad** and a cheat sheet of its
  controls. Flashing asks first (turn off with *Ask Before Flashing* or "Don't ask again").
- **Open MicroPad Studio…**, **Launch at Login**, **Quit**.
- **App keys** — a template can make the spare keys F13–F20 open an app or start dictation; only
  the config currently on the pad is active:
  - **Open Muse** — opens Meta Muse or brings it to the front.
  - **Dictate** — **tap to start, tap again to stop** (the text is kept). The Muse template brings
    Muse forward first; Finder & System dictates into whatever app you're in.
  - Needs **Accessibility** for MicroPad Menu (System Settings → Privacy & Security).
- Command line: `"dist/MicroPad Menu.app/Contents/MacOS/MicroPad Menu" --flash <template>`.

## Built-in templates

| Template | Highlights |
|---|---|
| Finder & System | Dictate anywhere, mute, Focus on/off\*, Terminal here\*, window screenshot, hidden files; knob = volume |
| Meta Muse | Open Muse, Dictate, Read response aloud, screenshot → clipboard, stop, send; knob = scroll / paste |
| Claude Code | Interrupt, permission mode, rewind, transcript, background, slash menu; knob = prompt history |
| VS Code | Command palette, quick open, terminal, comment, go to definition, format; knob = tabs / save |
| Git (Terminal) | Status, diff, stage all, commit, push, pull (oh-my-zsh git aliases); knob = shell history |
| iTerm2 · Chrome · Notion · Evernote | Tabs, navigation, search and formatting |
| iMovie · GIMP · Zoom | Editing tools, brush size, meeting controls |
| Total Annihilation (Windows) | Commander, select same type, stop, attack, patrol, reclaim; knob = game speed |

\* needs a one-time shortcut binding — run `bash scripts/setup_finder_shortcuts.sh` (backs up your
settings first) or set them in System Settings → Keyboard → Keyboard Shortcuts.

Shortcuts are each app's defaults; Meta Muse publishes none, so its *Stop* key is a best guess.

## Pad limits (enforced by the app — the CLI's `validate` misses them)
- **At most 5 key combinations per button** (`a,b,c,d,e`). Longer sequences silently fail on the pad.
- **No `{delay(...)}` options** — this model rejects them mid-upload, leaving the pad half-flashed.
- **One layer** — there's no layer-switch button, so extra layers are unreachable.
- The pad seems to send a key's press and release together when you let go, so hold-to-talk
  doesn't work — hence tap-to-toggle Dictate.
- Uploads take 60–75 s (the USB library is slow to scan the bus); the app waits up to 120 s.

## Config format
Same YAML as ch57x-keyboard-tool, plus documentation comments the tool ignores:

```yaml
# @title Zoom (macOS)
# @summary Mute, video, share and chat on dedicated keys.
# @note b1-1 Mute / unmute | ⌘⇧A toggles your microphone.     # b<row>-<col>, knob-ccw|press|cw
# @app f13 com.meta.endo                                       # F13 opens/focuses that app
# @app f14 +dictate                                            # F14 = dictate in the current app
model: ch57x-2
orientation: normal
rows: 2
columns: 3
knobs: 1
layers:
  - buttons:
      - ["cmd-shift-a", "cmd-shift-v", "cmd-shift-s"]
      - ["cmd-shift-h", "alt-y", "cmd-w"]
    knobs:
      - ccw: "volumedown"
        press: "cmd-shift-w"
        cw: "volumeup"
```

Key names come from `ch57x-keyboard-tool show-keys` (`escape`, not `esc`); actions reference:
[`doc/actions.md`](https://github.com/kriomant/ch57x-keyboard-tool/blob/master/doc/actions.md).

## Repository layout

| Path | Purpose |
|---|---|
| `MicroPadStudio/` | Studio app — `Model/` (YAML codec, templates, lint, descriptions), `Services/` (CLI wrapper, device, library, pad state, live test), `Views/` |
| `MicroPadMenu/` | Menu bar helper — model, app hotkeys / dictation, `--flash` CLI, selftest |
| `templates/` | Built-in templates (bundled into both apps) |
| `mapping.yaml` | Original single-layer test mapping (`a s d` / `z x c`, knob ← / enter / →) |
| `design/` | App icon source + `make_icon.py` |
| `docs/screenshots/` | README screenshots (see *Screenshots* under Building) |
| `vendor/` | Bundled `ch57x-keyboard-tool` v1.7.0 universal binary (MIT) |
| `scripts/` | Packaging, signing, Finder shortcut setup, GUI-test helpers |
| `project.yml` | XcodeGen spec (the `.xcodeproj` is generated and gitignored) |
| `pickupandgo.md` / `MILESTONES.md` | Handoff log + original plan |

## Building

```bash
scripts/setup_signing.sh     # once: local code-signing identity (keeps macOS permissions across rebuilds)
scripts/package_dist.sh      # xcodegen + Release build of both apps → sign → dist/ + zip
```

Always package with `package_dist.sh`: re-signing ad-hoc changes the signature and macOS drops
the Input Monitoring / Accessibility grants. The signing certificate is self-signed, so other Macs
see an unidentified developer.

Requirements: macOS 14+, Xcode 27, XcodeGen. Yams is pinned to 6.2.2 in `project.yml`.

### Screenshots

The README images need no clicking — demo launch options put a fresh copy of Studio in the right
state, then `screencapture -l <window id>` grabs just that window:

```bash
open -n dist/MicroPadStudio.app --args --load-template zoom-macos [--select-key]
open -n dist/MicroPadStudio.app --args --open-guide meta-muse-macos
```

## Tests

```bash
B=dist/MicroPadStudio.app/Contents/MacOS/MicroPadStudio
$B --selftest mapping.yaml                 # codec, notes, lint, library, every template + its PDFs, CLI validate
$B --layout-test [--select-key | --guide]  # offscreen layout check at the minimum window size

# Menu helper selftest — uses a fake pad tool and a temp folder, never touches the pad
MICROPAD_SUPPORT_DIR=/tmp/mp MICROPAD_TOOL_PATH=/path/to/fake-tool \
  "dist/MicroPad Menu.app/Contents/MacOS/MicroPad Menu" --selftest
```

Diagnostics: MicroPad Menu logs app-key presses to `~/Library/Logs/MicroPad Menu.log`.
Shared state lives in `~/Library/Application Support/MicroPadStudio/` (`configs/`, `pad-state.json`, `upload.lock`).

## Manual CLI workflow (still works)

```bash
ch57x-keyboard-tool validate < templates/zoom-macos.yaml   # config goes via stdin
ch57x-keyboard-tool upload   < templates/zoom-macos.yaml   # USB cable required; overwrites the pad
```
