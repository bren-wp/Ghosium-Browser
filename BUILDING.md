# Building Ghosium Browser 0.0.3

## Release baseline

The active product version is `0.0.3`. Windows and Android artifacts in one production release must come from the exact same Git commit.

## Windows canonical build

Windows x64 is built from the exact Chromium source revision in `ENGINE_SOURCE_REVISION` with the exact `DEPOT_TOOLS_REVISION`. Production must not use floating engine branches, precompiled browser snapshots or unreviewed source edits.

`.github/workflows/full-source-windows-build.yml` performs source-builder/toolchain preflight, patch-anchor verification, pinned Chromium bootstrap, Ghosium source transformation, deterministic GN configuration, full browser compilation, runtime/security verification, performance evidence, canonical Setup/Portable packaging, install-update-uninstall smoke testing, production Authenticode signing, update-manifest binding, provenance and SHA-256 generation.

Production `main` builds require the controlled self-hosted Windows source builder and the configured Brendigo code-signing certificate/private key. Signing requirements must not be downgraded to make a release pass.

## Android build

Android source is in `android/`.

Pinned release baseline:

```text
applicationId  com.brendigo.ghosium
minSdk         29
compileSdk     36
targetSdk      36
versionCode    3
versionName    0.0.3
JDK            17
Gradle         8.13
```

GitHub-hosted builds install `platforms;android-36` and `build-tools;36.0.0`. Gradle 8.13 is downloaded over HTTPS and accepted only after SHA-256 `20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78` matches.

Typical local verification with equivalent tools:

```text
gradle --no-daemon -p android testDebugUnitTest lintDebug lintRelease assembleDebug assembleRelease
```

The project treats lint warnings as errors except the narrowly documented dependency-version check and `OldTargetApi`. API 37 was not promoted into 0.0.3 because the stable GitHub-hosted SDK channel used by the release pipeline did not expose `platforms;android-37`; the product remains on stable API 36 rather than depending on a preview SDK.

## Android production signing

Production uses a stable Android signing identity supplied only through GitHub Actions secrets. Private key material must never be committed.

Required secrets:

```text
GHOSIUM_ANDROID_KEYSTORE_BASE64
GHOSIUM_ANDROID_KEYSTORE_PASSWORD
GHOSIUM_ANDROID_KEY_ALIAS
GHOSIUM_ANDROID_KEY_PASSWORD
```

The production workflow decodes the keystore only into the ephemeral runner, verifies the alias, builds the minified release APK, verifies it with Android `apksigner`, confirms package/version with `aapt`, records the signer certificate SHA-256 and deletes the runner with the job.

## Production orchestration

`.github/workflows/ghosium-0.0.3-production-release.yml` is triggered by the exact main-branch marker `.release/ghosium-v0.0.3.request`.

Release order is intentionally fail-closed:

1. validate version + marker;
2. build/test/lint/minify/sign/verify Android 0.0.3;
3. upload Android provenance artifact;
4. verify that `ghosium-v0.0.3` does not already exist;
5. dispatch the canonical full-source Windows production workflow on the exact `main` SHA;
6. require the complete Windows build/signing/publish workflow to succeed;
7. attach the previously verified Android APK to that immutable release;
8. verify Setup, Portable and Android APK assets all exist.

## Security boundary

No build optimization may disable browser sandboxing, GPU sandboxing, site/process isolation, Safe Browsing, TLS/certificate validation, extension trust or package/update signature verification. Android likewise keeps Safe Browsing and TLS verification, blocks mixed content and does not bypass certificate errors.
