#!/bin/bash
# Build Release, sign with the stable local identity, and package dist/.
#   scripts/package_dist.sh            # build + sign + zip
#   SKIP_BUILD=1 scripts/package_dist.sh   # re-sign/re-zip the existing build
# Run scripts/setup_signing.sh once first.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="MicroPad Studio Local Signing"
KEYCHAIN="$HOME/Library/Keychains/micropad-signing.keychain-db"
PWFILE="$HOME/.config/micropad-studio/signing-keychain-password"
BUILT="DerivedData/Build/Products/Release/MicroPadStudio.app"
APP="dist/MicroPadStudio.app"

[ -f "$KEYCHAIN" ] || { echo "no signing keychain — run scripts/setup_signing.sh first" >&2; exit 1; }
security unlock-keychain -p "$(cat "$PWFILE")" "$KEYCHAIN"

if [ -z "${SKIP_BUILD:-}" ]; then
    xcodegen generate >/dev/null
    xcodebuild -project MicroPadStudio.xcodeproj -scheme MicroPadStudio \
        -configuration Release -derivedDataPath ./DerivedData build | grep -E "error:|BUILD"
fi

mkdir -p dist
rm -rf "$APP" dist/MicroPadStudio.zip
ditto "$BUILT" "$APP"

# Nested executable first (--deep does not reach Contents/Resources), then the bundle.
codesign --force --keychain "$KEYCHAIN" -s "$IDENTITY" "$APP/Contents/Resources/ch57x-keyboard-tool"
codesign --force --keychain "$KEYCHAIN" -s "$IDENTITY" "$APP"
codesign --verify --strict "$APP"
codesign -d -r- "$APP" 2>&1 | grep designated

(cd dist && ditto -c -k --keepParent MicroPadStudio.app MicroPadStudio.zip)
echo "packaged $APP + dist/MicroPadStudio.zip"
