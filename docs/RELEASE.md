# Ghosium 0.0.3 Release Procedure

The active product version is `0.0.3`.

## Release state

Ghosium Browser 0.0.3 is a release candidate until every exact-commit candidate, signing, provenance and publication gate below succeeds. The checked-in Windows stable update baseline remains fail-closed before publication.

## Canonical scope

The production release contains one exact source identity across Windows and Android. Required end-user assets are:

```text
Ghosium-Browser-Setup.exe
Ghosium-Browser-Portable.exe
Ghosium-Browser-Android.apk
```

The Windows packages come only from the canonical full-source build. The Android package comes only from the production Android signing path. QA/stub/unsigned candidate binaries must never be renamed or promoted as production artifacts.

## Phase 1 — version baseline

1. Review the 0.0.3 code, Android application, workflows and documentation on the version-advance branch.
2. Require normal PR contracts plus cross-platform QA to pass for the exact head SHA.
3. Require the Android release-candidate workflow to prove unit tests, release lint, minification and release assembly without using production private-key material.
4. Merge the version baseline into `main` only after those gates are green.

The version-baseline PR must not contain the production release marker.

## Phase 2 — exact candidate and marker promotion

1. Create `ghosium/release/0.0.3` from the exact approved `main` baseline.
2. Add exactly `.release/ghosium-v0.0.3.request` containing exactly `ghosium-v0.0.3`.
3. Run the full-source Windows candidate workflow against that exact release-branch SHA.
4. Require successful compile, runtime, benchmark, Setup/Portable, source/provenance and SHA-256 evidence.
5. Open a marker-only PR from `ghosium/release/0.0.3` to `main`.
6. Require the release-marker promotion contract to bind that exact candidate evidence to the marker PR.
7. Merge the marker-only PR only after the promotion contract succeeds.

## Phase 3 — production

The marker push to `main` triggers `.github/workflows/ghosium-0.0.3-production-release.yml`.

Production order is fail-closed:

1. validate `VERSION` and the exact release marker;
2. require the stable Android production signing secrets;
3. unit-test, lint, minify, assemble and sign the Android APK;
4. verify Android package/version and signature with Android build tools;
5. record Android SHA-256, byte size, source commit and signing-certificate SHA-256;
6. dispatch the canonical full-source Windows production workflow for the exact `main` SHA;
7. require Windows compile/runtime/performance/Setup/Portable/signing/provenance and release publication to succeed;
8. attach the already verified Android APK and Android provenance evidence to the same immutable GitHub release;
9. verify the release is not draft/prerelease and contains all three required end-user artifacts.

## Mandatory security gates

Safe Browsing, TLS/certificate validation, browser/renderer/GPU sandboxing, site/process isolation, extension verification, update hash/signature/publisher verification and third-party legal attribution must remain intact.

Windows benchmarks must not terminate pre-existing user browser sessions. Android must keep TLS errors fail-closed, mixed content blocked, third-party cookies blocked, direct WebView file/content access disabled and production private-key material outside the repository.

## Signing requirements

Windows production requires the controlled source builder with its configured Authenticode certificate/private key and timestamping configuration. Android production requires the stable Brendigo Android keystore supplied only through GitHub Actions secrets as documented in `BUILDING.md`.

A missing signing identity is a release blocker; signing checks must not be weakened or bypassed.

## Release decision

Canonical 0.0.3 publication is allowed only after exact candidate evidence, marker promotion, Android production signing and canonical Windows production signing/provenance all succeed. Publication is GitHub-only unless a separately reviewed change establishes another release destination.
