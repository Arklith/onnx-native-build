# onnx-native-build

Build pipeline that produces ONNX Runtime native binaries for Android (and later iOS) from the upstream Microsoft source. Output is published to GitHub Releases.

## Why this exists

Microsoft publishes the ONNX Runtime source on GitHub and a Pod for iOS, and pushes the npm `onnxruntime-react-native` package, but **stopped publishing the Android `.aar` to Maven Central after 1.22.0** (verified 2026-05-03 — Maven returns 404 for any `onnxruntime-android` version newer than 1.22.0). Projects that need a current Android build of ORT have to compile it themselves.

This repo automates that compile in GitHub Actions so the artifact is reproducible, immutably tagged, and easy to consume from a downstream project.

## What's in scope (Stage 1)

- ORT pinned at upstream tag **v1.24.3** via git submodule.
- One Android target ABI: **arm64-v8a** (covers ~95% of modern Android devices).
- CPU execution provider only.
- Output: `libonnxruntime.so` attached to GitHub Releases.
- CI validation: `file`, `llvm-readelf -d`, `llvm-nm` symbol-presence checks.

## What's out of scope (later stages)

| Stage | Adds |
|---|---|
| 2 | Static link + LTO + dead-code elimination flags. |
| 3 | `--minimal_build` + op-config to strip unused operators. |
| 4 | armeabi-v7a + iOS arm64 device + simulator + `.aar` / `.xcframework` packaging. |
| 5 | Tagged-release process formalisation, CHECKSUMS.md auto-update. |

## How to trigger a build

### Option 1 — manual (workflow_dispatch)

Go to the repo's [Actions tab](../../actions), select "Build ONNX Runtime — Android Stage 1", click "Run workflow". Useful during early iteration.

### Option 2 — tag push (release)

```bash
git tag v1.24.3-graim.0
git push --tags
```

The workflow runs and uploads `libonnxruntime.so` to a new GitHub Release.

## Where output goes

- **Workflow run artifact** — every successful run, downloadable from the Actions UI for ~90 days.
- **GitHub Release** — only on tag-push runs (`v1.24.3-graim.*`). Immutable URL per version.

## Stage 1 status

This stage is the toolchain pre-flight: prove that CMake + NDK + ORT's Python build wrapper produce a working `libonnxruntime.so`. No size optimisation yet — the artifact will be ~30-50 MB. Stages 2-3 reduce that.

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
