#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  inject.sh — Inject LendicTweak.dylib into blenka.ipa and repack
#
#  Requires (macOS only):
#    - insert_dylib  : github.com/Tyilo/insert_dylib
#    - ldid           : brew install ldid   (or sideloadly's ldid)
#    - unzip / zip    : system tools
#
#  Usage:
#    cd Y.Lendic/LendicTweak
#    ./tweak_build.sh     # builds LendicTweak.dylib first
#    ./inject.sh          # creates ../blenka_patched.ipa
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

IPA_IN="$ROOT_DIR/blenka.ipa"
IPA_OUT="$ROOT_DIR/blenka_patched.ipa"
DYLIB_SRC="$SCRIPT_DIR/LendicTweak.dylib"
WORK_DIR="$(mktemp -d)"

APP_NAME="Maple.app"
BINARY_NAME="Maple"

echo "══════════════════════════════════════════"
echo "  LendicTweak IPA Injector"
echo "══════════════════════════════════════════"

# ── Checks ────────────────────────────────────────────────────────────────
if [ ! -f "$IPA_IN" ]; then
    echo "❌ IPA not found: $IPA_IN"; exit 1
fi
if [ ! -f "$DYLIB_SRC" ]; then
    echo "❌ Dylib not found: $DYLIB_SRC"
    echo "   Run ./tweak_build.sh first"; exit 1
fi
if ! command -v insert_dylib &>/dev/null; then
    echo "❌ insert_dylib not found."
    echo "   Install: git clone https://github.com/Tyilo/insert_dylib && cd insert_dylib && xcodebuild && cp build/Release/insert_dylib /usr/local/bin/"
    exit 1
fi
if ! command -v ldid &>/dev/null; then
    echo "⚠️  ldid not found — skipping fakesign (install with: brew install ldid)"
fi

echo "📦 Extracting IPA..."
unzip -q "$IPA_IN" -d "$WORK_DIR"

APP_PATH="$WORK_DIR/Payload/$APP_NAME"
BINARY="$APP_PATH/$BINARY_NAME"
DYLIB_DEST="$APP_PATH/LendicTweak.dylib"

if [ ! -f "$BINARY" ]; then
    echo "❌ Binary not found at $BINARY"; exit 1
fi

# ── Copy dylib ────────────────────────────────────────────────────────────
echo "📋 Copying LendicTweak.dylib → $APP_NAME/"
cp "$DYLIB_SRC" "$DYLIB_DEST"
chmod 755 "$DYLIB_DEST"

# ── Fix install name ──────────────────────────────────────────────────────
echo "🔧 Fixing dylib install name..."
DYLIB_INSTALL_NAME="@executable_path/LendicTweak.dylib"
install_name_tool -id "$DYLIB_INSTALL_NAME" "$DYLIB_DEST" 2>/dev/null || true

# ── Inject LC_LOAD_DYLIB ──────────────────────────────────────────────────
echo "💉 Injecting load command into binary..."
insert_dylib \
    --strip-codesig \
    --all-yes \
    "$DYLIB_INSTALL_NAME" \
    "$BINARY" \
    "$BINARY"

echo "✅ Load command injected"

# ── Fakesign (for TrollStore / AltStore / Sideloadly) ────────────────────
if command -v ldid &>/dev/null; then
    echo "🔐 Fakesigning binary..."
    ldid -S "$BINARY"
    echo "🔐 Fakesigning dylib..."
    ldid -S "$DYLIB_DEST"
else
    echo "⚠️  Skipping fakesign (ldid not found)"
    echo "   Sideloadly / AltStore will resign on install anyway"
fi

# Remove old _CodeSignature so app doesn't fail signature check
find "$APP_PATH" -name "CodeResources" -path "*/_CodeSignature/*" -delete 2>/dev/null || true

# ── Repack IPA ────────────────────────────────────────────────────────────
echo "📦 Repacking IPA..."
rm -f "$IPA_OUT"
(cd "$WORK_DIR" && zip -qr "$IPA_OUT" Payload/)

rm -rf "$WORK_DIR"

echo ""
echo "══════════════════════════════════════════"
echo "  ✅ Done! Output: $IPA_OUT"
echo "══════════════════════════════════════════"
echo ""
echo "  Install with TrollStore, Sideloadly, or AltStore"
echo "  The app will use SoundCloud as fallback for unavailable tracks"
echo "  Backend: https://lendic.duckdns.org/api/lendic/*"
