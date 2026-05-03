#!/usr/bin/env bash
#
# Validate that the built libonnxruntime.so is a real Android arm64 ELF
# and exposes the C API symbols we need. Stage 1 smoke check — minimal
# coverage; Stages 2-3 will compare against this baseline for size.
#
# Required environment:
#   ANDROID_NDK_HOME — for llvm-readelf / llvm-nm.
#
# Usage:
#   scripts/validate-artifact.sh [abi]

set -euo pipefail

ABI="${1:-arm64-v8a}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
ARTIFACT="${REPO_ROOT}/build/${ABI}/Release/libonnxruntime.so"

if [ -z "${ANDROID_NDK_HOME:-}" ]; then
  echo "ERROR: ANDROID_NDK_HOME not set" >&2
  exit 1
fi

if [ ! -f "${ARTIFACT}" ]; then
  echo "ERROR: build artifact not found: ${ARTIFACT}" >&2
  exit 1
fi

NDK_TOOLS="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin"
READELF="${NDK_TOOLS}/llvm-readelf"
NM="${NDK_TOOLS}/llvm-nm"

if [ ! -x "${READELF}" ]; then
  echo "ERROR: llvm-readelf not found at ${READELF}" >&2
  exit 1
fi

echo "=== File type ==="
file "${ARTIFACT}"
echo

echo "=== ELF dynamic section (first 40 entries) ==="
"${READELF}" -d "${ARTIFACT}" | head -40
echo

echo "=== Required symbols check ==="
REQUIRED_SYMBOLS=(
  "OrtSessionOptionsAppendExecutionProvider_CPU"
  "OrtGetApiBase"
)

MISSING=0
for sym in "${REQUIRED_SYMBOLS[@]}"; do
  if "${NM}" --defined-only "${ARTIFACT}" 2>/dev/null | grep -q "${sym}"; then
    echo "  OK:      ${sym}"
  else
    echo "  MISSING: ${sym}" >&2
    MISSING=1
  fi
done

if [ "${MISSING}" -ne 0 ]; then
  echo
  echo "ERROR: required symbols missing — build is a stub or wrong configuration" >&2
  exit 1
fi

echo
echo "=== File size baseline ==="
SIZE_BYTES=$(stat -c%s "${ARTIFACT}")
SIZE_HUMAN=$(ls -lh "${ARTIFACT}" | awk '{print $5}')
echo "  Path: ${ARTIFACT}"
echo "  Size: ${SIZE_HUMAN} (${SIZE_BYTES} bytes)"
echo
echo "Stage 1 baseline recorded. Stages 2-3 should produce smaller artifacts."
