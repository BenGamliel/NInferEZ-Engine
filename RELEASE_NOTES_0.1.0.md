# NInferEZ Engine 0.1.0 preview line

This is the first NInferEZ Engine Windows distribution line, based on
`iamwavecut/ninfer-all` commit `91576f32ee6147c31d5ead49393cce049530b6e1`.

It adds repeatable target-specific Windows build and packaging support for `sm86`, `sm89` and
`sm120a`, machine-readable engine identity/capabilities, a host-only NInfer v3 artifact inspector,
Windows/MSVC compatibility fixes, and support for the F32 `ssm_alpha.weight` variant used by some
GSQ-RCO GGUF exports.

This release publishes three separate native Windows x64 packages:

- `sm86` for NVIDIA compute capability 8.6, with known profiles for RTX 3090 / 3090 Ti;
- `sm89` for NVIDIA compute capability 8.9, with a known profile for RTX 4090;
- `sm120a` for NVIDIA compute capability 12.0a, with known profiles for RTX 5090 and RTX PRO 6000
  Blackwell.

Unlisted devices on the same architecture use runtime calibration. Model and context size remain
limited by available VRAM. The GSQ-RCO/GGUF-block execution path is available in all three builds;
full NVFP4 model execution requires `sm120a`. The `sm86` and `sm89` packages remain Preview pending
community qualification on physical hardware. A build succeeding does not promote a target to
Stable.

Preview archives are not Authenticode-signed. Verify the published SHA-256 and the included
`SHA256SUMS.txt`; `engine-manifest.json` records `codeSigned: false` explicitly.
