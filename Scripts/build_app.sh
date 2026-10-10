#!/bin/bash
# Build MicroPadStudio.app from the SPM package.
# Usage: Scripts/build_app.sh [--debug]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG=release
[[ "${1:-}" == "--debug" ]] && CONFIG=debug

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"
BIN=$(swift build -c "$CONFIG" --show-bin-path)

APP=dist/MicroPadStudio.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BIN/MicroPadStudio" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"

# Bundle the ch57x-keyboard-tool CLI (used for validate + upload).
CLI="$HOME/.local/bin/ch57x-keyboard-tool"
if [[ -x "$CLI" ]]; then
  cp "$CLI" "$APP/Contents/Resources/ch57x-keyboard-tool"
else
  echo "WARNING: $CLI not found; flashing will be unavailable" >&2
fi

echo "==> adhoc codesign"
codesign --force --deep -s - "$APP"

echo "==> built $APP"
