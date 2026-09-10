# Ghosium 0.0.3 Release Procedure

The active product version is `0.0.3`.

## Current release state

**Ghosium Browser 0.0.3 is a canonical production candidate and is not yet published as the canonical production release.**

Earlier GitHub Preview artifacts are intentionally distinct from the canonical full-source production release and cannot substitute for source-build, production signing, canonical Portable provenance or stable updater gates.

The checked-in stable update baseline remains fail-closed.

## Canonical production scope

The canonical 0.0.3 production path carries current Ghosium/Brendigo public branding, native New Tab integration, privacy/stability hardening, `ghost://` WebUI namespace, 38-locale contract, canonical Windows Setup/Portable packaging and fail-closed update/signing/provenance controls.

## Canonical candidate sequence

1. Merge the reviewed 0.0.3 production baseline only after its normal PR contracts pass.
2. Create `ghosium/release/0.0.3` from the exact approved production baseline with exactly `.release/ghosium-v0.0.3.request` containing `ghosium-v0.0.3`.
3. Let the existing release-request dispatcher launch the controlled full-source Windows candidate for that exact marker-branch SHA.
4. Require the candidate full-source workflow, runtime, benchmark, Setup/Portable, provenance and SHA-256 evidence to succeed.
5. Require the marker-only promotion contract to validate the exact candidate evidence.
6. Merge only the marker-only release PR to `main`.
7. Dispatch the canonical production `main` full-source workflow only after exact candidate/promotion evidence remains valid.
8. Require production signing and immutable canonical `ghosium-v0.0.3` GitHub publication.

## Mandatory public identity gates

Browser-owned user-visible names, Windows package metadata, installer surfaces and GitHub release metadata must use **Ghosium Browser / Ghosium / Brendigo**. Upstream technical identifiers may remain only where required for build/runtime compatibility. Third-party and open-source legal attribution must remain accurate.

## Mandatory security gates

Safe Browsing, TLS/certificate validation, browser/renderer/GPU sandboxing, site/process isolation, extension verification, update hash/signature/publisher verification and third-party legal attribution must remain intact.

## Canonical production artifacts

```text
Ghosium-Browser-Setup.exe
Ghosium-Browser-Portable.exe
```

Canonical evidence additionally includes builder readiness, exact source-build provenance, runtime verification, `GHOSIUM-PERFORMANCE.json`, source-stage provenance, canonical Setup smoke evidence, signed update-manifest evidence and `SHA256SUMS.txt`.

## Release decision

Canonical Ghosium Browser 0.0.3 publication is allowed only after the exact full-source candidate and production signing/provenance workflow succeeds. Publication in this project is GitHub-only unless a later separately reviewed change explicitly establishes another release destination.
