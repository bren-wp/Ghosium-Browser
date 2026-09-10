# Ghosium 0.0.3 Release Procedure

The checked-in stable update baseline remains fail-closed.

## Canonical production scope

## Canonical candidate sequence

1. Merge the reviewed 0.0.3 production baseline only after its normal PR contracts pass.

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

Canonical Ghosium Browser 0.0.3 publication is allowed only after the exact full-source candidate and production signing/provenance workflow succeeds. Publication in this project is GitHub-only unless a later separately reviewed change explicitly establishes another release destination.
