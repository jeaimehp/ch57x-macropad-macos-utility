#!/bin/bash
# One-time: create a stable self-signed code-signing identity for MicroPad Studio.
#
# Why: ad-hoc signatures change with every build, and macOS binds the Input
# Monitoring (TCC) grant to the exact binary — so every rebuild lost Live Test
# permission. A fixed certificate gives a stable designated requirement, so the
# grant survives rebuilds.
#
# The identity lives in its own keychain (not login), unlocked with a local
# password so codesign never prompts. It is only trusted by this Mac's TCC for
# this app; it is not an Apple-issued certificate (Gatekeeper still treats the
# app as unidentified when copied to another Mac).
#
# Idempotent: re-running does nothing if the identity already exists.
set -euo pipefail

IDENTITY="MicroPad Studio Local Signing"
KEYCHAIN="$HOME/Library/Keychains/micropad-signing.keychain-db"
PWFILE="$HOME/.config/micropad-studio/signing-keychain-password"

if [ -f "$KEYCHAIN" ] && security find-certificate -c "$IDENTITY" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "identity '$IDENTITY' already present in $KEYCHAIN"
    exit 0
fi

mkdir -p "$(dirname "$PWFILE")"
if [ ! -f "$PWFILE" ]; then
    (umask 077; openssl rand -hex 24 > "$PWFILE")
fi
PW="$(cat "$PWFILE")"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $IDENTITY
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -config "$WORK/cert.cnf" 2>/dev/null
# macOS `security import` only reads legacy-PBE PKCS#12 files.
openssl pkcs12 -export -legacy -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
    -name "$IDENTITY" -out "$WORK/id.p12" -passout pass:"$PW"

[ -f "$KEYCHAIN" ] || security create-keychain -p "$PW" "$KEYCHAIN"
security set-keychain-settings "$KEYCHAIN"          # no auto-lock timeout
security unlock-keychain -p "$PW" "$KEYCHAIN"
security import "$WORK/id.p12" -k "$KEYCHAIN" -P "$PW" -T /usr/bin/codesign
# Allow codesign to use the key without a GUI prompt.
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$PW" "$KEYCHAIN" >/dev/null

# Add to the user search list (keeping existing keychains) so codesign finds it.
if ! security list-keychains -d user | grep -q "micropad-signing"; then
    # shellcheck disable=SC2046
    security list-keychains -d user -s $(security list-keychains -d user | tr -d '"') "$KEYCHAIN"
fi

echo "created identity '$IDENTITY' in $KEYCHAIN"
