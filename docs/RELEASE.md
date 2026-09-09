# Ghosium 0.0.1 Release Procedure

The active development version is `0.0.1`.

## 0.0.1 release scope

0.0.1 is the clean Ghosium Browser baseline. It carries the current Ghosium branding, native Chromium New Tab integration, privacy/stability hardening, `ghost://` WebUI namespace, 38-locale contract, canonical Windows Setup/Portable packaging and fail-closed update/signing/provenance controls.

The checked-in update baseline remains disabled until a real verified production package exists.

## Candidate sequence

1. Merge the version-advancing 0.0.1 baseline PR only after repository/source contracts are green.
2. Create `ghosium/release/0.0.1` from the exact merged `main` commit.
3. Add exactly `.release/ghosium-v0.0.1.request` containing `ghosium-v0.0.1`.
4. Require the controlled full-source Windows candidate workflow to succeed for the exact release-branch SHA.
5. Require compile, runtime, benchmark, Setup/Portable, provenance and SHA-256 evidence.
6. Promote only the marker-only release PR for the exact candidate SHA.
7. Run the separate production `main` workflow.
8. Require production signing and immutable `ghosium-v0.0.1` publication.

## Mandatory security gates

Safe Browsing, TLS/certificate validation, browser/renderer/GPU sandboxing, site/process isolation, extension verification, update hash/signature/publisher verification and third-party legal attribution must remain intact.

## Required public artifacts

```text
Ghosium-Browser-Setup.exe
Ghosium-Browser-Portable.exe
```

Required evidence includes builder readiness, exact source-build provenance, runtime verification, `GHOSIUM-PERFORMANCE.json`, source-stage provenance, canonical Setup smoke evidence, update-manifest evidence and `SHA256SUMS.txt`.

## Release decision

Do not merge or publish 0.0.1 merely because hosted source contracts are green. A source audit, documentation cleanup or patch-only result is not a production browser release. Publication requires the exact 0.0.1 full-source candidate and production gates to succeed.
