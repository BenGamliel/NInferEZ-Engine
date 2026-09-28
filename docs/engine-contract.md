# NInferEZ Engine discovery contract

NInferEZ and other launchers discover an engine before starting a model. Discovery is host-only:
none of these commands initializes CUDA, loads weights or allocates VRAM.

## Binary identity

```powershell
.\ninfer-serve.exe --version-json
```

The response contains `schemaVersion`, `product`, `engineVersion`, `contractVersion`, `buildId`,
`platform`, `cudaArchitecture`, `upstream` and `unofficialDistribution`.

## Capabilities

```powershell
.\ninfer-serve.exe --capabilities-json
```

The response repeats the identity and declares the artifact container version, supported model
families, KV formats, speculative backends, API compatibility and build-specific native weight
formats. A client must not infer native NVFP4 support from a GPU name; it must read
`features.nativeNvfp4Weights`.

Clients must reject a higher `contractVersion` they do not understand. Within a known contract
version they must ignore unknown fields, so capabilities can be extended without requiring a
manager update.

## Artifact inspection

```powershell
.\ninfer-inspect.exe --model D:\Models\model.ninfer --json --estimate-memory
```

The inspector validates the NInfer v3 directory and every object range without reading the full
weight payload. It returns metadata, provenance, components, encoded sizes, weight formats,
speculative-model features and compatibility with the current build. Failures use a stable shape:

```json
{
  "schemaVersion": 1,
  "contractVersion": 1,
  "valid": false,
  "error": { "code": "artifact_invalid", "message": "human-readable detail" }
}
```

`memoryEstimate.runtimeVramAvailable` is intentionally `false`: exact runtime VRAM also depends on
the selected GPU, context capacity, KV format, speculation, concurrency and workspaces. Runtime
preflight belongs to a later engine contract and must not be approximated from file size.

## Release manifest

Every ZIP contains `engine-manifest.json`; every GitHub release also carries a small external
`release-manifest-sm<arch>.json`. They identify the architecture, version, upstream commit,
Preview/Stable qualification and archive SHA-256. They never execute commands or supply arbitrary
environment variables.
