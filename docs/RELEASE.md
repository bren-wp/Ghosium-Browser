# Ghosium 0.0.1 Release Procedure

The active product version is `0.0.1`.

## Current public release

**Ghosium Browser 0.0.1 Preview 1** is publicly available as `ghosium-v0.0.1-preview.1`.

This public build uses the verified GitHub-hosted pinned Chromium snapshot release path previously used for the superseded 0.1.8 Preview. Its Setup passed install → runtime → same-Setup update → runtime → uninstall verification, and the release includes Preview provenance, smoke evidence, SHA-256 checksums and build status.

The Preview is intentionally distinct from the canonical full-source production release. It does not claim a full Chromium source build, production Authenticode signing, canonical Portable provenance or stable updater enablement.

The checked-in stable update baseline remains disabled for the Preview.

## 0.0.1 canonical production scope

The canonical 0.0.1 production path carries the current Ghosium branding, native Chromium New Tab integration, privacy/stability hardening, `ghost://` WebUI namespace, 38-locale contract, canonical Windows Setup/Portable packaging and fail-closed update/signing/provenance controls.

## Canonical candidate sequence

1. Keep the clean 0.0.1 source baseline immutable while candidate evidence is generated.
2. Use `ghosium/release/0.0.1` with exactly `.release/ghosium-v0.0.1.request` containing `ghosium-v0.0.1`.
3. Require the controlled full-source Windows candidate workflow to succeed for the exact release-branch SHA.
4. Require compile, runtime, benchmark, Setup/Portable, provenance and SHA-256 evidence.
5. Require current `main` to remain source-equivalent to the verified candidate apart from reviewed release-control/documentation state.
6. Run the separate production `main` workflow.
7. Require production signing and immutable canonical `ghosium-v0.0.1` publication.

## Mandatory security gates

Safe Browsing, TLS/certificate validation, browser/renderer/GPU sandboxing, site/process isolation, extension verification, update hash/signature/publisher verification and third-party legal attribution must remain intact.

## Public Preview artifacts

```text
Ghosium-Browser-Setup.exe
GHOSIUM-PREVIEW-BUILD.json
GHOSIUM-PREVIEW-SETUP-SMOKE.json
SHA256SUMS.txt
BUILD-STATUS.txt
```

## Canonical production artifacts

```text
Ghosium-Browser-Setup.exe
Ghosium-Browser-Portable.exe
```

Canonical evidence additionally includes builder readiness, exact source-build provenance, runtime verification, `GHOSIUM-PERFORMANCE.json`, source-stage provenance, canonical Setup smoke evidence, signed update-manifest evidence and `SHA256SUMS.txt`.

## Release decision

The public **0.0.1 Preview 1** is a valid downloadable Preview release because its pinned-snapshot package and installer lifecycle evidence passed the dedicated Preview workflow. It must not be represented as the canonical full-source production release.

Canonical production publication remains gated on the exact full-source candidate and production signing/provenance workflow. Preview publication is not a substitute for those gates.
