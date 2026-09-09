# Building Ghosium Browser

## Current baseline

The active product version is `0.0.1`. This is the only active version documented for the current Ghosium product line.

Ghosium Browser is built from the exact Chromium source revision in `ENGINE_SOURCE_REVISION` with the exact `DEPOT_TOOLS_REVISION`. Production builds must not use floating branches, moving tags, precompiled browser snapshots or unreviewed local source edits.

## Build chain

The controlled Windows x64 build performs:

1. source-builder/toolchain preflight;
2. exact pinned-source anchor verification;
3. complete Ghosium branding and Windows identity transform;
4. native New Tab and privacy hardening;
5. public-surface/account/promo removal and localization;
6. `ghost://` internal WebUI routing verification;
7. native performance-default verification;
8. deterministic GN generation;
9. full browser and technical installer compilation;
10. compiled runtime/security verification;
11. source-built benchmark evidence;
12. canonical Setup and Portable packaging;
13. install/update/uninstall smoke tests;
14. production signing, update-manifest binding, provenance and SHA-256 gates on `main`.

The canonical workflow is `.github/workflows/full-source-windows-build.yml`.

## Security boundary

The 0.0.1 build must preserve browser/renderer/GPU sandboxing, site/process isolation, Safe Browsing, TLS/certificate validation, extension trust and update verification. Security-reducing flags are not accepted as performance optimizations.

## Privacy and performance defaults

The 0.0.1 Windows source configuration includes `enable_background_mode = false` and native Memory Saver. The source transform also blocks third-party cookies by default, disables search suggestions, network prediction/preloading, remote alternate-error pages, remote NTP Doodles and NTP prefetch/prerender triggers for new/default profiles.

Ghosium 0.0.1 supports 38 locales; English (`en-US`) is default and Croatian (`hr`) is required.

Do not publish performance claims until the compiled source-built 0.0.1 binary has produced verified `GHOSIUM-PERFORMANCE.json` evidence.

## Public artifacts

```text
Ghosium-Browser.exe
Ghosium-Proxy.exe
Ghosium-Browser-Setup.exe
Ghosium-Browser-Portable.exe
```

Internal Chromium/GN target names may remain where required by the build graph. They are implementation details, not public product branding.

## Release rule

A candidate uses `ghosium/release/0.0.1` with exactly one `.release/ghosium-v0.0.1.request` marker. Production publication remains a separate `main` gate and requires the exact intended source tree, full-source evidence, runtime/performance evidence, canonical package provenance and required signing validation.
