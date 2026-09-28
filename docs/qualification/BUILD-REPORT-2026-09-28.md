# NInferEZ Engine build report — 2026-09-28

## Scope and test boundary

The owner requested that no GPU tests run during this development pass. Every result below is a
compile, package, executable-contract or host-only artifact-directory check. No model weights were
loaded into VRAM, no CUDA inference kernel was launched and no throughput claim was re-measured.

## Source and toolchain

- Product: NInferEZ Engine `0.1.0-preview.1`
- Upstream: `iamwavecut/ninfer-all` commit `91576f32ee6147c31d5ead49393cce049530b6e1`
- Release identity: the tag, embedded `buildId`, release manifest and archive checksum are the
  authoritative identifiers for the published package
- Platform: Windows x64
- CMake: 4.3.1
- MSVC: 19.44.35229
- CUDA compiler: 13.1, build `cuda_13.1.r13.1/compiler.37061995_0`
- Dependencies: repository-local `.deps/vcpkg-deps/installed/x64-windows`

## sm120a / RTX 5090 and Blackwell

Status: **Preview package ready for NInferEZ integration; host checks passed.** Stable hardware
qualification remains pending because GPU tests were explicitly deferred.

Built products:

- `build-sm120a/apps/ninfer-serve.exe` — 1,064,990,720 bytes
- `build-sm120a/apps/ninfer-inspect.exe` — 242,688 bytes
- `build-sm120a/apps/ninfer.exe` — built successfully but excluded from the lightweight package to
  avoid duplicating the full static CUDA kernel set

Host-only contract checks passed:

- product identity, version, contract version and `sm120a` architecture;
- capabilities JSON, OpenAI Responses declaration and `rk8v4` declaration;
- structured JSON error for an invalid artifact path;
- package execution with a clean `PATH`;
- ZIP hash, SPDX JSON, per-file hashes and runtime dependency presence.

Host-only model inspection passed for both existing local artifacts:

| artifact | artifact ID | file bytes | compatibility result |
| --- | --- | ---: | --- |
| OrcaRouter GSQ-RCO IQ3_XXS | `4e57396a0e464016838b6f5cd8092b2e` | 10,796,696,832 | valid v3; GGUF block formats; MTP present; compatible with `sm120a` |
| Swift Qwen3.8-27B NVFP4 | `23304a1c23394835888166e699c75969` | 22,783,241,220 | valid v3; NVFP4/FP8/groupwise formats; Vision, MTP and DFlash2 present; native NVFP4 compatible |

Inspection validates the artifact directory and object ranges; it does not prove generation
quality or runtime performance.

## Release package

- Archive naming: `NInferEZ-Engine-0.1.0-preview.1-sm120a-windows-x64.zip`
- Exact size, SHA-256 and source build ID are generated after the release commit and published in
  `release-manifest-sm120a.json` and the adjacent `.sha256` file
- Channel: Preview / build-verified
- Authenticode: not signed; this is stated in both manifests
- Models bundled: none
- Default payload: `ninfer-serve`, `ninfer-inspect`, cuBLAS/cuBLASLt, FFmpeg, curl, zlib,
  app-local Visual C++ runtime, legal notices, SPDX inventory and hashes

## Deferred GPU targets

The `sm86`/RTX 3090 build was deliberately stopped when the owner reprioritized the 5090 product.
Its partial incremental state is preserved under `build-sm86/`; its log is preserved at
`.local/build-logs/sm86.log`. At suspension, 800 Ninja log entries and 4 of the 28 largest
long-context attention translation units had completed. No `sm86` release binary or package is
claimed.

The `sm89`/RTX 4090 build was not started. Source, build scripts, manifests and Preview policy for
both targets remain in the repository so work can resume later without recreating the design.

## Qualification still required for Stable

On explicit approval and an idle matching GPU, this exact package still needs model load,
deterministic generation, API, representative context/KV, speculative-backend, VRAM and throughput
checks. Until then, the correct label is Preview—not Stable.
