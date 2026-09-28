# NInferEZ Engine for Windows

This archive is an unofficial Windows distribution of NInfer based on `iamwavecut/ninfer-all`.
It is not affiliated with or endorsed by the upstream maintainers. See `UPSTREAM.md`,
`LICENSING.md`, `THIRD-PARTY-NOTICES.txt` and `licenses/` for source lineage and legal notices.

## Choose the correct package

Each archive contains native CUDA code for one GPU family. `engine-manifest.json` records the
target and release status.

| archive target | compatible GPU architecture | known profile targets | release status before hardware qualification |
| --- | --- | --- | --- |
| `sm86` | NVIDIA compute capability 8.6 | GeForce RTX 3090 / 3090 Ti | Preview |
| `sm89` | NVIDIA compute capability 8.9 | GeForce RTX 4090 | Preview |
| `sm120a` | NVIDIA compute capability 12.0a | GeForce RTX 5090 and RTX PRO 6000 Blackwell | Preview or Stable as declared in the manifest |

An unlisted GPU may use the package for its compute capability; the engine calibrates an unknown
device profile on first use. Model size, context and concurrency still have to fit its available
VRAM. A marketing series name alone is not a compatibility check, so launchers should select the
package from the CUDA compute capability reported by the installed device.

Do not use a package built for another architecture. NVFP4 weight artifacts require the `sm120a`
package. GGUF-block/GSQ-RCO artifacts and the documented groupwise formats use the compatibility
routes available in the corresponding `sm86`, `sm89` and `sm120a` builds.

## Requirements

- Windows 11 x64;
- the GPU matching this archive and a recent NVIDIA driver;
- a supported NInfer v3 `.ninfer` artifact.

The archive carries its app-local Microsoft Visual C++ runtime and its FFmpeg, libcurl, zlib and
cuBLAS runtime closure. The CUDA Toolkit, CMake, Git and Visual Studio are not required on the
computer that runs it. GPU drivers and model files are not included.

The standard engine archive contains `ninfer-serve.exe` and the host-only `ninfer-inspect.exe`.
The one-shot `ninfer.exe` CLI statically duplicates the large CUDA kernel set, so it is excluded
from the lightweight default archive; source builders can build it normally or package it with
`scripts\package-release.ps1 -IncludeCli`.

## Verify the package and model

`SHA256SUMS.txt` contains a SHA-256 entry for every packaged file. `engine-manifest.json` is the
machine-readable identity consumed by NInferEZ and other clients. Preview archives are currently
unsigned, so verify the release SHA-256 before extracting them; the manifest reports
`codeSigned: false` rather than implying a signature exists.

```powershell
.\ninfer-serve.exe --version-json
.\ninfer-serve.exe --capabilities-json
.\ninfer-inspect.exe --model D:\Models\model.ninfer --json
```

Inspection reads and validates the artifact directory without loading model weights and without
allocating VRAM. It reports exact encoded sizes. Runtime VRAM cannot be inferred from file size
alone because it also depends on GPU, context, KV storage, speculation, concurrency and workspaces.

## Minimal start

The conservative command below binds only to the local computer. It does not enable a speculative
backend that the selected model might not contain.

```powershell
.\ninfer-serve.exe D:\Models\model.ninfer `
  --host 127.0.0.1 --port 8080 `
  --max-context 8192 --kv-capacity auto --kv-headroom-mib 2048 `
  --kv-dtype int8
```

When `/health` reports ready, clients may connect directly to the engine. The server supports the
OpenAI Chat Completions and Responses APIs and the Anthropic Messages-compatible endpoint declared
by `--capabilities-json`.

```powershell
Invoke-RestMethod http://127.0.0.1:8080/health
```

Run `.\ninfer-serve.exe --help` for advanced context, KV, MTP, DFlash/DFlash2, cache, concurrency,
vision and API controls. A speculative backend must exist in the model; `ninfer-inspect` reports
the embedded model components.

## Security and errors

The default host is loopback. Binding to `0.0.0.0` exposes the API to the network; set an API key
and use an appropriate firewall/reverse proxy before doing so. Startup errors name invalid model,
option, compatibility and memory conditions and exit non-zero.

No model license is granted by this engine package. Review the license of every model or converted
artifact separately.
