#!/usr/bin/env bash
#
# Build ONNX Runtime for an Android ABI from upstream source.
# Stage 1: arm64-v8a only, CPU EP only, no DCE/strip yet.
#
# Required environment:
#   ANDROID_NDK_HOME — path to Android NDK r26b (or compatible)
#   ANDROID_HOME     — path to Android SDK
#
# Usage:
#   scripts/build-android.sh [abi]
#   abi defaults to arm64-v8a.

set -euo pipefail

ABI="${1:-arm64-v8a}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
ORT_DIR="${REPO_ROOT}/ort"
OUTPUT_DIR="${REPO_ROOT}/build/${ABI}"

if [ -z "${ANDROID_NDK_HOME:-}" ]; then
  echo "ERROR: ANDROID_NDK_HOME not set" >&2
  exit 1
fi
if [ -z "${ANDROID_HOME:-}" ]; then
  echo "ERROR: ANDROID_HOME not set" >&2
  exit 1
fi
if [ ! -d "${ORT_DIR}" ]; then
  echo "ERROR: ORT submodule not found at ${ORT_DIR}" >&2
  echo "  Run: git submodule update --init --recursive" >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

echo "=== Build config ==="
echo "  ABI:               ${ABI}"
echo "  ORT source:        ${ORT_DIR}"
echo "  Output dir:        ${OUTPUT_DIR}"
echo "  Android API level: 24"
echo "  ANDROID_NDK_HOME:  ${ANDROID_NDK_HOME}"
echo "  ANDROID_HOME:      ${ANDROID_HOME}"
echo "  CPU only:          yes (NNAPI disabled)"
echo

cd "${ORT_DIR}"

python tools/ci_build/build.py \
  --android \
  --android_abi "${ABI}" \
  --android_api 24 \
  --android_sdk_path "${ANDROID_HOME}" \
  --android_ndk_path "${ANDROID_NDK_HOME}" \
  --build_dir "${OUTPUT_DIR}" \
  --config Release \
  --build_shared_lib \
  --parallel \
  --skip_tests \
  --use_nnapi=0

echo
echo "=== Build complete ==="
ls -lh "${OUTPUT_DIR}/Release/libonnxruntime.so" 2>/dev/null || {
  echo "WARNING: libonnxruntime.so not found at expected path; ORT may have used a different output layout." >&2
  find "${OUTPUT_DIR}" -name 'libonnxruntime.so' -ls 2>/dev/null || true
}
