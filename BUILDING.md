# Building Ghosium Browser

## Current baseline

The active product version is `0.0.2`. This is the only active version documented for the current Ghosium development line.

Ghosium Browser's canonical production path is built from the exact Chromium source revision in `ENGINE_SOURCE_REVISION` with the exact `DEPOT_TOOLS_REVISION`. Production builds must not use floating branches, moving tags, precompiled browser snapshots or unreviewed local source edits.

Previously published or candidate releases remain separate release classes and do not establish canonical 0.0.2 full-source production evidence.

## Canonical build chain

The controlled Windows x64 full-source build performs:

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

The 0.0.2 build must preserve browser/renderer/GPU sandboxing, site/process isolation, Safe Browsing, TLS/certificate validation, extension trust and update verification. Security-reducing flags are not accepted as performance optimizations.

The Windows updater stages downloads in a unique session directory under the secure Windows temporary directory before enforcing exact endpoint, no-redirect, size, SHA-256, Authenticode publisher and signed PE product/company/version checks. NSIS resolution rejects arbitrary user-writable PATH executables; the portable fallback remains exact-version and SHA-256 pinned with HTTPS-only redirects.

## Privacy and performance defaults

The 0.0.2 Windows source configuration includes `enable_background_mode = false` and native Memory Saver. The source transform also blocks third-party cookies by default, disables search suggestions, network prediction/preloading, remote alternate-error pages, remote NTP Doodles and NTP prefetch/prerender triggers for new/default profiles.

Performance measurement tooling refuses to overwrite an existing Ghosium user session and scopes forced cleanup to process trees rooted in launchers created by the benchmark. Cross-browser comparisons skip already-running browsers rather than killing user-owned processes.

Ghosium 0.0.2 supports 38 locales; English (`en-US`) is default and Croatian (`hr`) is required.

Performance claims for canonical production must remain tied to verified `GHOSIUM-PERFORMANCE.json` evidence from the full-source workflow.

## Public artifacts

Canonical full-source production contract:

```text
Ghosium-Browser.exe
Ghosium-Proxy.exe
Ghosium-Browser-Setup.exe
Ghosium-Browser-Portable.exe
```

Internal Chromium/GN target names may remain where required by the build graph. They are implementation details, not public product branding.

## Release rule

Ghosium Browser 0.0.2 may be published as canonical production only after the exact intended source tree, full-source evidence, runtime/performance evidence, canonical Setup/Portable provenance and required signing validation have passed. GitHub publication must not be inferred from a development branch or from an earlier release.
