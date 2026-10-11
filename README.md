# NInferEZ Engine

A Windows x64 distribution of [iamwavecut/ninfer-all](https://github.com/iamwavecut/ninfer-all), providing a standalone inference server, GPU-specific packages and a host-only model inspector.

**Prefer a desktop application? [NInferEZ Manager](https://github.com/BenGamliel/NInferEZ-Manager) downloads the matching engine and manages models, profiles, API access and logs.**

[Download 1.0.0](https://github.com/BenGamliel/NInferEZ-Engine/releases/tag/v1.0.0) · [Engine contract](docs/engine-contract.md) · [Models](https://huggingface.co/2beng2) · [Converter](https://github.com/BenGamliel/NInferEZ-Converter)

<img src="assets/NInferEZ-Engine.png" alt="NInferEZ Engine" width="96">

## Choose a package

| GPU target | Download | Compute capability | Native NVFP4 | Qualification |
|---|---|---|---|---|
| RTX 3000 / compatible Ampere | [sm86](https://github.com/BenGamliel/NInferEZ-Engine/releases/download/v1.0.0/NInferEZ-Engine-1.0.0-sm86-windows-x64.zip) | 8.6 | No | Community Preview |
| RTX 4000 / compatible Ada | [sm89](https://github.com/BenGamliel/NInferEZ-Engine/releases/download/v1.0.0/NInferEZ-Engine-1.0.0-sm89-windows-x64.zip) | 8.9 | No | Community Preview |
| RTX 5000 / compatible Blackwell | [sm120a](https://github.com/BenGamliel/NInferEZ-Engine/releases/download/v1.0.0/NInferEZ-Engine-1.0.0-sm120a-windows-x64.zip) | 12.0 | Yes | RTX 5090 measurements available; other cards are Community Preview |

The `a` in `sm120a` is a target suffix, not a compute capability of 12.0a. See [NVIDIA's GPU table](https://developer.nvidia.com/cuda/gpus). These packages are not universal builds for every NVIDIA GPU. CUDA 13.1 dependencies are included; a compatible installed driver is required.

Extract the complete package. It contains `ninfer-serve.exe`, `ninfer-inspect.exe`, runtime libraries, branding, licenses, manifest, SBOM and checksums. Packages are unsigned and contain no model weights.

## Runtime capabilities

- Supported NInfer v3 Qwen hybrid Dense/MoE artifacts, including compatible Qwen3.6/3.8 derivatives.
- Supported native encodings and imported GGUF blocks; an arbitrary GGUF file is not a NInfer artifact.
- MTP, DFlash and DFlash2 when the artifact includes the required components.
- Text, optional vision, structured output, prefix caching and the KV formats reported by the runtime.
- OpenAI-compatible Chat Completions/Responses and supported Messages serving.
- Machine-readable identity, capabilities and structural inspection for integrations.

Support depends on the encoded tensors, architecture, components, GPU target and memory. A valid v3 container does not guarantee that every model will run. Native NVFP4/FP8 support is target-specific.

## Quick start

```powershell
.\ninfer-serve.exe --version-json
.\ninfer-serve.exe --capabilities-json
.\ninfer-inspect.exe --model .\model.ninfer --json --estimate-memory
.\ninfer-serve.exe .\model.ninfer --max-context 32768 --kv-capacity 32768 --kv-dtype rk8v4 --max-concurrency 1
```

Run from the extracted folder. The serving command is a conservative text example, not the fastest profile for every model. Use Manager or the model card for acceleration/vision choices. Host-only inspection does not measure runtime VRAM or model quality.

## Performance and release scope

The inference libraries and CUDA kernels are unchanged from the previously measured NInferEZ build. Version 1.0.0 updates product identity, branding and distribution metadata; it does not introduce a quantizer or claim new speed results.

Measurements are published with their exact artifact/configuration:

- [OrcaRouter IQ3_XXS: MTP/DFlash2 and long context](https://huggingface.co/2beng2/Qwen3.8-27B-OrcaRouter-GSQ-RCO-IQ3_XXS-NInfer)
- [Swift NVFP4: quality evaluations and decode speed](https://huggingface.co/2beng2/Swift-1.5-Qwen3.8-27B-Uncensored-NVFP4-NInfer)
- [Heretic IQ2_XS: compact text artifact](https://huggingface.co/2beng2/Qwen3.8-27B-Heretic-GSQ-RCO-IQ2_XS-NInfer)

Hardware qualification is separate from product numbering. Untested GPU/model combinations remain Community Preview. Build/host checks do not qualify GPU behavior.

## Source and license

Use `scripts/build.ps1` with a matching CUDA target; see the [build system guide](docs/maintainer/build-system.md) and [Windows distribution requirements](docs/release-archive-windows.md). Preserve [Apache-2.0](LICENSE), [upstream provenance](UPSTREAM.md), [contributors](CONTRIBUTORS.md), [licensing](LICENSING.md) and [third-party notices](THIRD-PARTY-NOTICES.txt).

NInferEZ Engine is an independent fork/distribution of ninfer-all, itself based on NInfer. It is not an official upstream or NVIDIA release. Packaged CUDA, Visual C++, FFmpeg and other dependencies retain their own redistribution terms.
