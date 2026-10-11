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
PRODUCTS="DerivedData/Build/Products/Release"
APPS=("MicroPadStudio.app" "MicroPad Menu.app")

[ -f "$KEYCHAIN" ] || { echo "no signing keychain — run scripts/setup_signing.sh first" >&2; exit 1; }
security unlock-keychain -p "$(cat "$PWFILE")" "$KEYCHAIN"

if [ -z "${SKIP_BUILD:-}" ]; then
    xcodegen generate >/dev/null
    for scheme in MicroPadStudio MicroPadMenu; do
        xcodebuild -project MicroPadStudio.xcodeproj -scheme "$scheme" \
            -configuration Release -derivedDataPath ./DerivedData build | grep -E "error:|BUILD"
    done
fi

mkdir -p dist
rm -f dist/MicroPadStudio.zip
for name in "${APPS[@]}"; do
    app="dist/$name"
    rm -rf "$app"
    ditto "$PRODUCTS/$name" "$app"
    # Nested executable first (--deep does not reach Contents/Resources), then the bundle.
    codesign --force --keychain "$KEYCHAIN" -s "$IDENTITY" "$app/Contents/Resources/ch57x-keyboard-tool"
    codesign --force --keychain "$KEYCHAIN" -s "$IDENTITY" "$app"
    codesign --verify --strict "$app"
    codesign -d -r- "$app" 2>&1 | grep designated
done

(cd dist && zip -qry MicroPadStudio.zip MicroPadStudio.app "MicroPad Menu.app")
echo "packaged dist/{MicroPadStudio,MicroPad Menu}.app + dist/MicroPadStudio.zip"
