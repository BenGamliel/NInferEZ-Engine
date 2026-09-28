# Cutting a NInferEZ Engine Windows release

> Replaced by NInferEZ Engine in 2026. Upstream release history remains in Git and in the archived
> upstream release notes.

All GPU packages come from the same source commit. Architecture-specific forks are not permitted.

## 1. Prepare

1. Synchronize the `upstream` remote and record the exact base/update in `UPSTREAM.md`.
2. Set the NInferEZ Engine SemVer in `VERSION` and update `RELEASE_NOTES_<major.minor.patch>.md`.
3. Run the license/payload audit in `LICENSING.md`; do not assume a previous CUDA or vcpkg payload
   has unchanged terms.
4. Confirm `git diff --check` and the host-only engine contract test pass.

## 2. Build the matrix

Dependencies remain under this repository's ignored `.deps/` directory. On a clean development
machine, run `scripts/bootstrap-dependencies.ps1` once.

```powershell
.\scripts\build.ps1 -Arch 86   -Target ninfer,ninfer-serve,ninfer-inspect
.\scripts\build.ps1 -Arch 89   -Target ninfer,ninfer-serve,ninfer-inspect
.\scripts\build.ps1 -Arch 120a -Target ninfer,ninfer-serve,ninfer-inspect
```

Building proves source/toolchain compatibility only. It does not prove behavior on a GPU family.

## 3. Package

```powershell
.\scripts\package-release.ps1 -Arch 86   -Channel preview
.\scripts\package-release.ps1 -Arch 89   -Channel preview
.\scripts\package-release.ps1 -Arch 120a -Channel preview
```

The packager verifies the configured architecture, collects the runtime DLL closure and required
legal texts, runs `--help` and the JSON contract with a clean `PATH`, writes the inner checksums and
SPDX inventory, and produces one ZIP plus one external release manifest per target. The lightweight
default package omits the duplicate one-shot CLI; use `-IncludeCli` only for a separate CLI-oriented
archive.

Never edit a finished archive. Rebuild it and regenerate its hashes.

## 4. Qualification status

- `preview`: build completed and host-only package checks passed; upstream evidence may exist, but
  this exact package has not passed physical-card qualification.
- `stable`: this exact package passed model load, coherent generation, API and representative
  memory/context checks on the declared GPU family.

The packager refuses `-Channel stable` unless `-QualificationReport <file.json>` identifies the
same CUDA architecture, records `gpuUsed: true` and reports a passing run.

RTX 3090 and RTX 4090 remain Preview until community results contain the package SHA-256, GPU,
driver, model hash, command/profile and logs. Compilation alone never promotes them.

## 5. GPU qualification

Qualification is opt-in and runs only on a machine owner-approved idle GPU. At minimum:

- load one supported standard/groupwise artifact and serve a deterministic request;
- exercise the API health/load paths and a model-supported speculative backend;
- verify context/KV behavior representative of that GPU's VRAM;
- record peak VRAM, load time, throughput and complete logs;
- for `sm120a`, also load an NVFP4 artifact;
- compare against the recorded baseline and investigate changes over 5%.

No model is copied into the repository or release archive.

## 6. Publish

Create an annotated Git tag from the reviewed commit and upload the three ZIPs, their
`release-manifest-sm*.json` files and a channel manifest to the configured GitHub repository.
Attach the source repository as a fork/derivative, retain the complete upstream attribution, and
state Preview/Stable status per target in the release notes.
