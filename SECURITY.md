# Ghosium Browser Security Policy

## Supported release

Only the newest stable Ghosium Browser release is supported with security fixes. Older releases should be upgraded.

## Windows security baseline

Ghosium inherits a large security surface from its exact pinned upstream browser engine. Each Windows release therefore pins `ENGINE_SOURCE_REVISION`, applies reviewed transforms and reruns the full source/runtime/release pipeline.

The product does not disable browser/renderer/GPU sandboxing, site/process isolation, Safe Browsing, TLS/certificate validation, extension trust or update verification for performance.

Production Windows publication requires successful source compilation, runtime smoke tests, measured performance evidence, canonical Setup + Portable provenance, install/update/uninstall validation, valid Authenticode signatures, update-manifest binding and SHA-256 evidence.

## Android security baseline

Android 0.0.3 targets API 36 with minimum API 29 and uses Android System WebView. Ghosium configures WebView to block mixed content and third-party cookies, disables direct file/content access, keeps Safe Browsing enabled where supported and cancels SSL errors. Renderer-process termination is handled through a controlled recovery path rather than leaving the activity in an invalid state.

Non-HTTP(S) external schemes are not launched silently; the user sees a confirmation first. File selection is delegated to Android's system document picker.

Browser-local Android data is explicitly excluded from cloud backup and device-to-device transfer.

## Android release signing

The production APK must be signed with the stable Brendigo Android release identity supplied through GitHub Actions secrets. Private key material must never be committed to the repository. Production verifies the APK with `apksigner`, records the signer certificate SHA-256, confirms package/version metadata and binds SHA-256 + byte size + source commit in `GHOSIUM-ANDROID-RELEASE.json`.

If Android signing secrets are unavailable or verification fails, the 0.0.3 production orchestrator stops before dispatching the Windows production release.

## Release completeness

A 0.0.3 release is complete only when the exact release contains:

```text
Ghosium-Browser-Setup.exe
Ghosium-Browser-Portable.exe
Ghosium-Browser-Android.apk
```

and all platform-specific signing/provenance gates have succeeded.

## Reporting

Use the repository private vulnerability reporting / Security Advisory flow when available. Reports should include the Ghosium version, platform/OS version, minimal reproduction steps, expected/observed behavior and whether the issue appears specific to Ghosium-owned code.

Public security page: https://ghosium.com/security
