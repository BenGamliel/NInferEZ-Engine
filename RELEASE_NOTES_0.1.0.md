# NInferEZ Engine 0.1.0 preview line

This is the first NInferEZ Engine Windows distribution line, based on
`iamwavecut/ninfer-all` commit `91576f32ee6147c31d5ead49393cce049530b6e1`.

It adds repeatable target-specific Windows build and packaging support for `sm86`, `sm89` and
`sm120a`, machine-readable engine identity/capabilities, a host-only NInfer v3 artifact inspector,
Windows/MSVC compatibility fixes, and support for the F32 `ssm_alpha.weight` variant used by some
GSQ-RCO GGUF exports.

This release publishes the `sm120a` package for RTX 5090 and compatible Blackwell cards. RTX 3090
and RTX 4090 source targets remain prepared for later Preview builds and community testing; they
are not release assets in this version. A build succeeding does not promote a target to Stable.

Preview archives are not Authenticode-signed. Verify the published SHA-256 and the included
`SHA256SUMS.txt`; `engine-manifest.json` records `codeSigned: false` explicitly.
