# onnx-native-build

Build pipeline that produces ONNX Runtime native binaries for Android (and later iOS) from the upstream Microsoft source. Output is published to GitHub Releases.

## Why this exists

Microsoft publishes the ONNX Runtime source on GitHub and a Pod for iOS, and pushes the npm `onnxruntime-react-native` package, but **stopped publishing the Android `.aar` to Maven Central after 1.22.0** (verified 2026-05-03 — Maven returns 404 for any `onnxruntime-android` version newer than 1.22.0). Projects that need a current Android build of ORT have to compile it themselves.

This repo automates that compile in GitHub Actions so the artifact is reproducible, immutably tagged, and easy to consume from a downstream project.

## What's in scope (Stage 1 + .aar packaging)

- ORT pinned at upstream tag **v1.24.3** via git submodule.
- One Android target ABI: **arm64-v8a** (covers ~95% of modern Android devices).
- CPU execution provider only.
- Output (per release):
  - `libonnxruntime.so` — raw shared library (~19MB stripped).
  - `onnxruntime-android-arklith.aar` — minimal Android Archive consumable from Gradle, containing the `.so` plus ORT public headers (`headers/onnxruntime_cxx_api.h`, etc.) and `jni/arm64-v8a/libonnxruntime.so`. Filename matches the consumer's CMake glob `onnxruntime-android-*.aar`.
  - `CHECKSUMS.txt` — SHA256 of both artifacts for Gradle download verification.
- CI validation: `file`, `llvm-readelf -d`, `llvm-nm` symbol-presence checks (for `.so`); `unzip -l` structural self-check (for `.aar`, run by `scripts/package-aar.sh`).

## What's out of scope (later stages)

| Stage | Adds |
|---|---|
| 2 | Static link + LTO + dead-code elimination flags. |
| 3 | `--minimal_build` + op-config to strip unused operators (drops ~19MB → ~3-5MB). |
| 4 | armeabi-v7a + iOS arm64 device + simulator + `.xcframework` packaging. |
| 5 | Tagged-release process formalisation, CHECKSUMS.md auto-update across versions. |

## How to trigger a build

### Option 1 — manual (workflow_dispatch)

Go to the repo's [Actions tab](../../actions), select "Build ONNX Runtime — Android Stage 1", click "Run workflow". Useful during early iteration.

### Option 2 — tag push (release)

```bash
git tag v1.24.3-arklith.1
git push --tags
```

The workflow runs and uploads `libonnxruntime.so`, `onnxruntime-android-arklith.aar`, and `CHECKSUMS.txt` to a new GitHub Release. Use the next available tag in the `v1.24.3-arklith.*` sequence (e.g. `v1.24.3-arklith.2`, `.3`) for subsequent builds.

## Where output goes

- **Workflow run artifact** — every successful run, downloadable from the Actions UI for ~90 days. Bundle includes the `.so`, the `.aar`, and `CHECKSUMS.txt`.
- **GitHub Release** — only on tag-push runs (`v1.24.3-arklith.*`). Immutable URL per version. Same three artifacts attached.

## Stage 1 + Path B beta-shortcut status

This stage is the toolchain pre-flight: prove that CMake + NDK + ORT's Python build wrapper produce a working `libonnxruntime.so`. No size optimisation yet — the `.so` is ~19MB stripped, the `.aar` is ~21MB. Stages 2-3 reduce that to ~3-5MB.

The `.aar` packaging is the **Path B beta-shortcut**: enables a downstream consumer (e.g. an Expo/React Native fork that expects an Android Archive at gradle build time) to use this binary today, ahead of the full Stage 4 multi-ABI packaging. The fork pins the URL + SHA256 of a specific release tag, and Gradle downloads + verifies on each build.

## Pinned toolchain

| Tool | Version |
|---|---|
| Java | 17 (Temurin) |
| Python | 3.11 |
| CMake | 3.28.x |
| Android NDK | r26b |
| Runner | `ubuntu-latest` (GitHub-hosted) |

## License

MIT for the build scripts and workflow definition. The ONNX Runtime source code in `ort/` retains its upstream Microsoft MIT license.

## See also

- ONNX Runtime upstream: https://github.com/microsoft/onnxruntime
- Stage plan: private project notes, available on request.
