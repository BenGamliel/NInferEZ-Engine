# Upstream and local change record

NInferEZ Engine is a thin Windows distribution fork of
[`iamwavecut/ninfer-all`](https://github.com/iamwavecut/ninfer-all). It is not affiliated with or
endorsed by NInfer or the upstream maintainers.

## Current base

- Upstream repository: `https://github.com/iamwavecut/ninfer-all.git`
- Base commit: `91576f32ee6147c31d5ead49393cce049530b6e1`
- Base commit date: 2026-09-27
- First NInferEZ Engine release line: `0.1.0-preview.1`

The repository keeps the upstream Git commit as its base and uses an `upstream` remote. Upstream
authors, contributor records and provenance documentation remain in the tree.

## Intentional local changes

1. Replace the GCC-only `__builtin_ctz` use in a CUDA host path with the C++20
   `std::countr_zero` equivalent so MSVC builds the same operation.
2. Generate built-in device-profile JSON from bounded string chunks to avoid MSVC C2026 without
   changing the JSON payload.
3. Split the serving option parser into two sequential groups to avoid MSVC C1061 without changing
   accepted flags or defaults.
4. Accept third-party GSQ-RCO GGUF exports that retain `ssm_alpha.weight` in F32 and convert only
   that small direct projection to BF16. Quantized GGUF block matrices remain byte-for-byte copied.
5. Add a target-aware Windows build/release pipeline for `sm86`, `sm89` and `sm120a`.
6. Add stable JSON identity/capability commands and a host-only `.ninfer` inspector for NInferEZ
   and other clients.

None of these changes inserts a proxy into the inference path. Model execution, HTTP serving and
CUDA kernels continue to run directly in the NInfer engine.

## Updating from upstream

An upstream update must be merged as history, not copied over the tree. Reapply only the local
changes still needed, then build every target. Runtime qualification is recorded separately per
GPU family: a successful compile is Preview evidence, not Stable hardware qualification.
