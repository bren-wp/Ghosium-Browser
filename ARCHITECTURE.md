# Ghosium Browser 0.0.3 Architecture

## Product scope

Ghosium 0.0.3 has two first-class client targets sharing one release identity:

- Windows x64 source-built browser, Setup and Portable distribution;
- Android 10+ native browser shell using the platform WebView.

Both targets are versioned `0.0.3` and are published from the same Git commit.

## Windows source boundary

The repository does not vendor the complete Chromium source tree. It stores the exact upstream source/tool revisions, Ghosium branding and product metadata, reviewed source transformations, deterministic Windows build configuration, installer/release tooling and independent verification contracts.

The controlled source builder fetches the exact pinned engine, applies Ghosium transforms, verifies the resulting source, compiles the browser, smoke-tests the runtime, measures performance and packages canonical Setup and Portable artifacts.

Ghosium-owned desktop UI uses Ghosium/Brendigo identity and `ghost://` / `ghost-untrusted://` internal namespaces. Technical Chromium/GN identifiers may remain only where required by the upstream build graph or legal attribution.

## Windows profile and Portable boundary

Installed profile root:

```text
%LOCALAPPDATA%\Brendigo\Ghosium\User Data
```

Portable data root is located beside the Portable executable and is injected through the launcher's private `--ghosium-portable-profile=` contract. User-supplied protected arguments cannot override the profile, bundled privacy extension or configured locale.

Portable runtime files are extracted into a versioned local cache. A staging directory is promoted only after extraction succeeds; a ready marker distinguishes complete caches from interrupted ones. Existing complete caches are reused.

## Android boundary

Android package: `com.brendigo.ghosium`.

`MainActivity` owns the native browser chrome and lifecycle. Web content is rendered by Android System WebView; Ghosium does not bundle a second embedded browser engine in the APK. The app provides local New Tab content through the app-assets HTTPS origin, navigation controls, downloads, file selection, fullscreen, Desktop Site, find/share controls and browser-data cleanup.

Android privacy/security configuration blocks third-party cookies, forbids mixed content, disables WebView file/content access, keeps Safe Browsing enabled, cancels TLS certificate errors, confirms external URI schemes and recovers from renderer termination. Browser-local app data is excluded from cloud backup and device transfer.

## Update and release trust boundary

Windows native update validation enforces the exact first-party HTTPS endpoint, package size/SHA-256, Authenticode publisher and signed PE metadata before Setup execution.

Android 0.0.3 does not introduce an unsigned self-updater. The release APK is signed with the stable Brendigo Android identity, verified with `apksigner`, and its package/version/hash/signer fingerprint are recorded as release evidence.

The 0.0.3 orchestrator will not start Windows production release work until Android production signing/build verification has succeeded. The release is considered complete only after the same GitHub release contains Setup, Portable and Android APK.

## Performance model

Windows performance evidence comes from the controlled source-built 1/5/10-tab benchmark. Android avoids unnecessary WebView recreation, preserves/restores WebView state and uses renderer recovery rather than crashing the activity. Neither platform permits security-reducing flags as a performance shortcut.

## Legal boundary

Brendigo-authored Ghosium material follows the repository product license. Chromium, Android WebView, AndroidX, Material Components and other third-party components remain under their respective licenses and trademark terms.
