# ch57xx-micropad

Key-mapping project for a **3×2 + 1 knob CH57x macro pad** (USB `1189:8890`),
programmed with
[ch57x-keyboard-tool](https://github.com/kriomant/ch57x-keyboard-tool) (v1.7.0,
installed at `~/.local/bin/ch57x-keyboard-tool`).

## Layout of this repo

| File | Purpose |
|---|---|
| `mapping.yaml` | Active key-mapping config (2×3 buttons + 1 knob, 3 layers) |

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
