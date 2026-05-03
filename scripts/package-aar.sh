#!/usr/bin/env bash
# Package the freshly-built libonnxruntime.so + ORT public C/C++ headers into
# a minimal Android .aar consumable by graim's onnxruntime-react-native fork.
#
# Run after build-android.sh + validate-artifact.sh. CWD must be the repo root
# (the GitHub Actions workflow invokes us via `bash scripts/package-aar.sh`).
#
# Output:
#   build/onnxruntime-android-arklith.aar (zip with headers/ + jni/<abi>/*.so + manifest + classes.jar)
#   build/onnxruntime-android-arklith.aar.sha256 (single-line SHA256 of the .aar)
#
# Layout matches the consumer fork's CMakeLists.txt glob:
#   file(GLOB onnxruntime_include_DIRS "${BUILD_DIR}/onnxruntime-android-*.aar/headers")
#   file(GLOB onnxruntime_link_DIRS    "${BUILD_DIR}/onnxruntime-android-*.aar/jni/${ANDROID_ABI}/")
#
# This is the Path B beta-shortcut packaging — arm64-v8a only, no LTO/DCE/op-stripping.
# Stage 2/3/4 will replace this with a smaller multi-ABI .aar via the same filename.

set -euo pipefail

ABI="arm64-v8a"  # currently the only ABI we build (Stage 1 — Stage 4 adds armeabi-v7a + iOS)
SO_PATH="build/${ABI}/Release/libonnxruntime.so"
ORT_INCLUDE="ort/include/onnxruntime/core"
STAGING="build/aar-staging"
OUT_AAR="build/onnxruntime-android-arklith.aar"

echo "[package-aar] Verifying inputs"
if [ ! -f "$SO_PATH" ]; then
  echo "[package-aar] ERROR: $SO_PATH not found — run build-android.sh first" >&2
  exit 1
fi
if [ ! -d "$ORT_INCLUDE" ]; then
  echo "[package-aar] ERROR: $ORT_INCLUDE not found — submodule missing?" >&2
  exit 1
fi

echo "[package-aar] Cleaning staging dir"
rm -rf "$STAGING" "$OUT_AAR"
mkdir -p "$STAGING/headers"
mkdir -p "$STAGING/jni/${ABI}"

echo "[package-aar] Copying ORT public headers (flat into headers/)"
# Public C/C++ session headers — onnxruntime_cxx_api.h transitively includes the rest
cp "$ORT_INCLUDE/session/"*.h "$STAGING/headers/"
# Provider factory headers — cpp/SessionUtils.cpp uses bare-filename includes for these
cp "$ORT_INCLUDE/providers/cpu/cpu_provider_factory.h"     "$STAGING/headers/"
cp "$ORT_INCLUDE/providers/nnapi/nnapi_provider_factory.h" "$STAGING/headers/"
cp "$ORT_INCLUDE/providers/coreml/coreml_provider_factory.h" "$STAGING/headers/"
HEADER_COUNT=$(find "$STAGING/headers" -maxdepth 1 -name '*.h' | wc -l)
echo "[package-aar] Copied $HEADER_COUNT headers"

echo "[package-aar] Copying libonnxruntime.so to jni/${ABI}/"
cp "$SO_PATH" "$STAGING/jni/${ABI}/libonnxruntime.so"

echo "[package-aar] Writing minimal AndroidManifest.xml"
cat > "$STAGING/AndroidManifest.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="ai.onnxruntime.arklith" />
EOF

echo "[package-aar] Generating empty classes.jar"
EMPTY_DIR="$STAGING/.empty-classes"
mkdir -p "$EMPTY_DIR"
# `jar cf` with an empty directory produces a valid (effectively empty) jar.
# --no-manifest would be ideal but Java 17's jar tool always writes META-INF/MANIFEST.MF;
# the manifest content is ABI-stable (no timestamps), so SHA reproducibility holds.
( cd "$EMPTY_DIR" && jar cf "../classes.jar" . )
rm -rf "$EMPTY_DIR"

echo "[package-aar] Normalizing file timestamps for reproducible SHA256"
find "$STAGING" -exec touch -d '1970-01-01T00:00:00Z' {} +

echo "[package-aar] Assembling .aar (zip)"
# -X strips extended attributes (uid/gid/extra fields) for reproducible output.
# -r recurses; -q quiet. Sort listing for deterministic central-directory order.
( cd "$STAGING" && find . -type f | LC_ALL=C sort | zip -X -q "../$(basename "$OUT_AAR")" -@ )

echo "[package-aar] Self-check: verify required entries are present"
REQUIRED=(
  "AndroidManifest.xml"
  "classes.jar"
  "headers/onnxruntime_cxx_api.h"
  "headers/onnxruntime_c_api.h"
  "headers/cpu_provider_factory.h"
  "headers/nnapi_provider_factory.h"
  "jni/${ABI}/libonnxruntime.so"
)
for entry in "${REQUIRED[@]}"; do
  if ! unzip -l "$OUT_AAR" | grep -qE "[[:space:]]${entry}\$"; then
    echo "[package-aar] ERROR: required entry missing from .aar: $entry" >&2
    echo "[package-aar] Full contents of $OUT_AAR:" >&2
    unzip -l "$OUT_AAR" >&2
    exit 1
  fi
done
echo "[package-aar] Self-check passed: all required entries present"

AAR_SIZE=$(stat -c '%s' "$OUT_AAR" 2>/dev/null || stat -f '%z' "$OUT_AAR")
SHA256=$(sha256sum "$OUT_AAR" | awk '{print $1}')
echo "$SHA256  $(basename "$OUT_AAR")" > "${OUT_AAR}.sha256"

echo "[package-aar] Done."
echo "[package-aar]   Output:    $OUT_AAR  ($AAR_SIZE bytes)"
echo "[package-aar]   SHA256:    $SHA256"
echo "[package-aar]   Sha file:  ${OUT_AAR}.sha256"
