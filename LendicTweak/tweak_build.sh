#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
#  tweak_build.sh — Build LendicTweak.dylib on macOS using Theos
#  Run this script on a Mac with Theos installed.
#  https://theos.dev/docs/installation
# ═══════════════════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check Theos
if [ -z "${THEOS:-}" ]; then
    export THEOS="$HOME/theos"
fi
if [ ! -d "$THEOS" ]; then
    echo "❌ Theos not found at $THEOS"
    echo "   Install: https://theos.dev/docs/installation"
    exit 1
fi

echo "🔨 Building LendicTweak.dylib with Theos at $THEOS..."
make clean
make

DYLIB_PATH=".theos/obj/LendicTweak.dylib"
if [ ! -f "$DYLIB_PATH" ]; then
    # Theos may output to different path depending on version
    DYLIB_PATH=$(find .theos/obj -name "*.dylib" | head -1)
fi

if [ -f "$DYLIB_PATH" ]; then
    cp "$DYLIB_PATH" LendicTweak.dylib
    echo "✅ Built: $SCRIPT_DIR/LendicTweak.dylib"
    echo "   Now run: ./inject.sh"
else
    echo "❌ Build failed — .dylib not found"
    exit 1
fi
