# NInferEZ Engine 1.0.0

Independent Windows distribution of [iamwavecut/ninfer-all](https://github.com/iamwavecut/ninfer-all), with complete upstream attribution and third-party notices.

- Separate Windows x64 packages for `sm86`, `sm89` and `sm120a`.
- Approved engine artwork, machine-readable version/capabilities contract and host-only artifact inspector.
- App-local CUDA, media, networking and Visual C++ dependencies; no developer toolchain required to run.
- NInfer v3 artifacts with the architectures, encodings and embedded components supported by the selected build. The format version alone does not guarantee every model is supported.
- Manager 1.0.0 downloads and verifies the appropriate package; the engine can also run independently.

The 1.0.0 host programs are compiled against the existing inference libraries and CUDA kernels from core build `69c75330`. This release changes product identity and distribution, not inference precision, kernel routes or benchmark settings. Previously recorded RTX 5090 measurements are linked from the model cards; they are not new benchmark runs on this release.

All packages are unsigned. `sm86` and `sm89` remain community-preview targets without local hardware qualification. RTX 5090 operation was tested in the preceding build; other compatible Blackwell cards remain unqualified. A successful compilation is not a guarantee that a model fits every card's VRAM.

Downloads include SHA-256 checksums, a package manifest, SPDX file inventory and dependency licenses. Model weights are not bundled.

[Manager](https://github.com/BenGamliel/NInferEZ-Manager) · [Converter](https://github.com/BenGamliel/NInferEZ-Converter) · [OrcaRouter models](https://huggingface.co/2beng2/Qwen3.8-27B-OrcaRouter-GSQ-RCO-IQ3_XXS-NInfer) · [Swift model](https://huggingface.co/2beng2/Swift-1.5-Qwen3.8-27B-Uncensored-NVFP4-NInfer)
