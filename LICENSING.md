# Licensing and attribution review

Review date: 2026-09-28

Status: initial publication review. This is an engineering compliance record, not legal advice.

## Reviewed upstream

- Immediate upstream: [`iamwavecut/ninfer-all`](https://github.com/iamwavecut/ninfer-all)
- Reviewed local revision: `91576f32ee6147c31d5ead49393cce049530b6e1`
- Upstream license: Apache License 2.0
- Upstream lineage described by the project: `iamwavecut/ninfer-all` consolidates work from `ashalliants/ninfer-3090`, `Don-Chad/ninfer-3090`, `Neroued/ninfer`, and other credited forks and contributors.
- The reviewed upstream tree has no root `NOTICE` file. It does contain an XGrammar `NOTICE` under `third_party/xgrammar`, which must remain with redistributed XGrammar material or be represented faithfully in an aggregate third-party notice.

This review applies to the upstream revision above. Before every public release, repeat the audit against the exact source revision and the exact binary payload being released.

## What the license permits

Subject to the conditions below, Apache-2.0 permits:

- use for private, public, and commercial purposes;
- modification of the source;
- distribution of source and compiled binaries;
- creation and distribution of derivative works;
- charging for the distribution, support, or warranty offered on our own behalf;
- keeping our own modifications private; Apache-2.0 does not require publication of modified source.

The license also includes a contributor patent grant. Filing patent litigation alleging that the work or an incorporated contribution infringes a patent can terminate the relevant patent license under Apache-2.0 section 3.

## Required for source distribution

Every public source release must:

1. Include the complete, unmodified Apache License 2.0 text in a root `LICENSE` file.
2. Retain applicable copyright, patent, trademark, and attribution notices from upstream source files.
3. Mark files we modify with a prominent notice that the file was changed. A concise header or a clear adjacent change notice is sufficient; do not erase the original notice.
4. Preserve the upstream attribution chain. Keep `CONTRIBUTORS.md`, the maintainer/provenance map, and relevant README credits, or carry their complete applicable content into equivalent documents.
5. Keep all vendored dependency license and notice files. Do not replace them with only a link.
6. Add our own copyright only to work we actually authored. It must appear alongside, not instead of, upstream ownership and attribution.
7. State clearly that this project is a modified, unofficial Windows distribution/fork and identify the exact upstream revision used.

Publishing a Git fork with history is preferred because it preserves authorship and provenance. If a clean snapshot is published instead, the attribution documents and modification notices become especially important.

## Required for binary distribution

Every installer, portable archive, and standalone binary release must include a readable legal bundle, for example:

```text
licenses/
  LICENSE-Apache-2.0.txt
  THIRD-PARTY-NOTICES.txt
  third_party/...
```

The binary legal bundle must include:

- the Apache-2.0 license text for NInfer/ninfer-all-derived code;
- the copyright and permission notices for every shipped MIT component;
- the Apache-2.0 license and applicable `NOTICE` content for XGrammar and DLPack;
- notices for any additional package actually present in the binary or installer payload;
- a short statement that the binary contains modifications, with our release version and the exact upstream commit.

The About/help output should make the same information discoverable, but an About screen alone is not a substitute for license files in the distribution.

## Third-party material found in the reviewed tree

| Component | License found in tree | Required release treatment |
| --- | --- | --- |
| cpp-httplib | MIT | Retain copyright and MIT permission text. |
| ggml-quants | MIT | Retain ggml authors' copyright and MIT permission text. |
| llama-jinja | MIT | Retain ggml authors' copyright and MIT permission text. |
| nlohmann/json | MIT | Retain Niels Lohmann copyright and MIT permission text. |
| spdlog | MIT | Retain Gabi Melman/contributors copyright and MIT permission text. |
| utf8proc | MIT-style terms with historical notices | Retain the complete supplied license file, including historical notices. |
| XGrammar | Apache-2.0 | Retain its license and its `NOTICE` attribution. |
| DLPack vendored by XGrammar | Apache-2.0 | Retain its license and applicable attribution. |

This table covers the source tree inspected on the review date. It is not yet a software bill of materials for a compiled Windows release.

## Windows binary dependencies still requiring release-time review

Before shipping binaries, generate an inventory from the exact installer and portable archive and review every bundled DLL and static library. In particular:

- CUDA Toolkit/runtime libraries are governed by NVIDIA terms, not by Apache-2.0. Bundle only files NVIDIA designates as redistributable, with the required notices.
- Microsoft Visual C++ runtime components must come only from the Visual Studio REDIST directory.
  NInferEZ Engine packages the three imported x64 CRT files app-local and includes a Microsoft
  runtime notice; the build operator remains responsible for complying with the applicable Visual
  Studio/Microsoft Software License Terms. Microsoft's current deployment guidance is
  <https://learn.microsoft.com/cpp/windows/redistributing-visual-cpp-files>.
- DirectStorage, D3D12 helper components, vcpkg packages, installer frameworks, icons, fonts, and WebUI assets each need their own license check if included.
- GPU drivers must never be copied into the product; document them as external prerequisites.

No binary release should be labelled license-complete until this payload-level audit is complete.

## Models and converted artifacts

The engine license does not grant rights to model weights, tokenizers, adapters, MTP heads, DFlash artifacts, converted `.ninfer` files, prompts, or model branding. Each model and source checkpoint must be reviewed under its own license and acceptable-use terms.

The safest engine release contains no model weights. NInferEZ should let the user select a model and should display the model package's own license/metadata when supplied.

## Name and affiliation

Apache-2.0 does not grant trademark or product-name rights except for reasonable attribution. No separate NInfer trademark permission was found in the reviewed upstream tree.

The name **NInferEZ Engine** may be used only with prominent origin wording such as:

> Unofficial Windows distribution of NInfer, based on iamwavecut/ninfer-all. Not affiliated with or endorsed by the upstream maintainers.

Do not use upstream logos as our product logo, imply endorsement, or describe the complete engine as authored solely by us. Our documentation may accurately describe and brand our Windows packaging, build system, manager integration, testing, and original modifications.

## Recommended public attribution block

Use this near the top of the public README and in release notes:

> NInferEZ Engine is an unofficial Windows distribution and derivative of [iamwavecut/ninfer-all](https://github.com/iamwavecut/ninfer-all), which is derived from NInfer and credited community forks. The engine code is distributed under the Apache License 2.0. Upstream authorship and third-party notices are retained in this repository and in binary release packages. This project is not affiliated with or endorsed by the upstream maintainers.

## Publication checklist

- [ ] Start from a clean, recorded upstream commit.
- [ ] Preserve Git history where practical.
- [ ] Include the unmodified root Apache-2.0 `LICENSE`.
- [ ] Preserve applicable upstream copyright and attribution notices.
- [ ] Preserve `CONTRIBUTORS.md` and the provenance/maintainer map.
- [ ] Add prominent changed-file notices to our modifications.
- [ ] Generate `THIRD-PARTY-NOTICES.txt` from the exact release payload.
- [ ] Audit all bundled Windows DLLs, static libraries, installer code, UI assets, and WebUI assets.
- [ ] Keep NVIDIA and Microsoft redistributables within their respective redistribution terms.
- [ ] Keep model files outside the engine release unless separately cleared.
- [ ] Include the unofficial-distribution and no-endorsement wording.
- [ ] Record the upstream commit, our version, build flags, CUDA version, supported GPU targets, and hashes.
- [ ] Check the release archives themselves before publishing; do not rely only on the source tree.

## Decision

Publication is feasible. The correct presentation is a clearly identified unofficial Windows distribution/fork, not an engine claimed as wholly original work. Source and commercial binary releases are allowed under Apache-2.0 when the obligations above and all third-party/runtime terms are satisfied.
