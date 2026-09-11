# Ghosium 0.0.2 Release Procedure

The active development product version is `0.0.2`.

## Current release state

**Ghosium Browser 0.0.2 is a hardening candidate and is not published as the canonical production release.**

Earlier releases and candidates are intentionally distinct from the canonical 0.0.2 full-source production release. Their evidence cannot substitute for the gates below.

The checked-in stable update baseline remains fail-closed.

## Canonical production scope

The canonical 0.0.2 production path carries the current Ghosium branding, native upstream New Tab integration, privacy/stability hardening, `ghost://` WebUI namespace, 38-locale contract, canonical Windows Setup/Portable packaging and fail-closed update/signing/provenance controls. The updater additionally requires unique secure temporary staging, and the release toolchain rejects arbitrary user-writable NSIS PATH resolution.

## Canonical candidate sequence

1. Merge the reviewed 0.0.2 production baseline only after its normal PR contracts pass.
2. Create `ghosium/release/0.0.2` from the exact approved production baseline with exactly `.release/ghosium-v0.0.2.request` containing `ghosium-v0.0.2` when the release-marker contract requires candidate promotion.
3. Require the controlled full-source Windows candidate workflow to succeed for the exact release-branch SHA.
4. Require compile, runtime, benchmark, Setup/Portable, provenance and SHA-256 evidence.
5. Require current `main` to remain source-equivalent to the verified candidate apart from reviewed release-control state.
6. Run the production `main` workflow required by the canonical release architecture.
7. Require production signing and immutable canonical `ghosium-v0.0.2` GitHub publication.

## Mandatory security gates

Safe Browsing, TLS/certificate validation, browser/renderer/GPU sandboxing, site/process isolation, extension verification, update hash/signature/publisher verification and third-party legal attribution must remain intact.

Updater staging must use the Windows secure temporary directory plus a unique per-update session directory before any Setup download. Browser benchmarks must never terminate pre-existing user browser sessions by image name.

## Canonical production artifacts

```text
Ghosium-Browser-Setup.exe
Ghosium-Browser-Portable.exe
```

Canonical evidence additionally includes builder readiness, exact source-build provenance, runtime verification, `GHOSIUM-PERFORMANCE.json`, source-stage provenance, canonical Setup smoke evidence, signed update-manifest evidence and `SHA256SUMS.txt`.

## Release decision

Canonical Ghosium Browser 0.0.2 publication is allowed only after the exact full-source candidate and production signing/provenance workflow succeeds. Publication in this project is GitHub-only unless a later separately reviewed change explicitly establishes another release destination.
