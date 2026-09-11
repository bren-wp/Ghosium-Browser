# Ghosium Browser for Android 0.0.3

## Baseline

- Package: `com.brendigo.ghosium`
- Version code: `3`
- Version name: `0.0.3`
- Minimum SDK: 29 (Android 10)
- Compile SDK: 36
- Target SDK: 36
- Java: 17
- Build system: Android Gradle Plugin 8.13.2 / Gradle 8.13

## Browser UI and lifecycle

The application uses Android System WebView inside a Ghosium-owned native activity. It implements address/search navigation, Back/Forward/Home/Reload, local New Tab, downloads, file chooser, fullscreen media, Desktop Site, Find in Page, Share, clear browsing data, deep-link handling, state restoration and renderer recovery.

English is the base Android resource language and Croatian is provided in `values-hr`.

## Privacy and security

- third-party WebView cookies disabled;
- mixed content never allowed;
- direct WebView file access disabled;
- direct WebView content access disabled;
- Safe Browsing enabled where supported;
- SSL errors are cancelled;
- external non-HTTP(S) schemes require confirmation;
- no analytics/advertising SDK;
- Android cloud backup and device transfer excluded for browser data.

## QA

The 0.0.3 quality workflow installs stable API 36/build-tools 36.0.0, verifies Gradle 8.13 by SHA-256 and runs unit tests + lint with warnings-as-errors + debug/release assembly. Debug APK signing is verified only as QA identity; it is not the production signing identity.

## Production signing

Production signing is supplied at runtime through GitHub Actions secrets. The keystore/private key is never checked into the repository. The production workflow verifies the APK with `apksigner`, confirms package/version via `aapt`, records APK SHA-256/size and signer certificate SHA-256, then publishes `Ghosium-Browser-Android.apk` only after those checks pass.

Required secret names are documented in the repository `BUILDING.md`.
