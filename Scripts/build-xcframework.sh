#!/bin/bash
#
# Reproducibly builds the Metal-enabled `whisper.xcframework` that WhisperMetalKit ships.
#
# It clones whisper.cpp at a pinned ref and runs the project's own `build-xcframework.sh`
# (GGML_METAL=ON, GGML_METAL_EMBED_LIBRARY=ON), then zips the result and prints the SwiftPM
# checksum so you can attach the zip to a GitHub Release and reference it from Package.swift.
#
# Usage:
#   Scripts/build-xcframework.sh [whisper.cpp-git-ref]
#
# Output:
#   ./whisper.xcframework        (for local development via .binaryTarget(path:))
#   ./whisper.xcframework.zip    (to upload to a GitHub Release)
#   prints: swift package checksum
#
set -euo pipefail

WHISPER_CPP_REF="${1:-master}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENDOR="$ROOT/vendor/whisper.cpp"

echo "==> whisper.cpp ref: $WHISPER_CPP_REF"

if [ ! -d "$VENDOR/.git" ]; then
    mkdir -p "$ROOT/vendor"
    git clone https://github.com/ggml-org/whisper.cpp.git "$VENDOR"
fi
git -C "$VENDOR" fetch --tags --force origin
git -C "$VENDOR" checkout "$WHISPER_CPP_REF"
echo "==> building at $(git -C "$VENDOR" rev-parse --short HEAD)"

# whisper.cpp's official builder (Metal ON, shaders embedded) → build-apple/whisper.xcframework
( cd "$VENDOR" && ./build-xcframework.sh )

rm -rf "$ROOT/whisper.xcframework" "$ROOT/whisper.xcframework.zip"
cp -R "$VENDOR/build-apple/whisper.xcframework" "$ROOT/whisper.xcframework"

# Deterministic zip for a stable checksum across machines.
( cd "$ROOT" && ditto -c -k --sequesterRsrc --keepParent whisper.xcframework whisper.xcframework.zip )

echo "==> done"
echo "xcframework: $ROOT/whisper.xcframework"
echo "zip:         $ROOT/whisper.xcframework.zip"
echo -n "checksum:    "
swift package --package-path "$ROOT" compute-checksum "$ROOT/whisper.xcframework.zip"
