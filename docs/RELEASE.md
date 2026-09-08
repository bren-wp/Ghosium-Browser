# Ghosium Production Release Procedure

## Current product version

The active development version is `0.1.4`.

Version policy:

- `0.x.0` — meaningful product/security/performance milestone;
- `0.x.y` — production correction or bounded product improvement.

Every production PR must advance `VERSION`. Ghosium Privacy, Ghosium Search, built-in Store metadata and the disabled Windows update baseline must remain synchronized.

New releases use the immutable namespace:

```text
ghosium-v0.1.0
ghosium-v0.1.1
ghosium-v0.1.2
ghosium-v0.1.3
ghosium-v0.1.4
ghosium-v0.2.0
```

Historical releases remain untouched.

## 0.1.4 release scope

The 0.1.4 line carries forward the 0.1.3 Search/performance/release hardening and additionally:

- makes `ghost://profiles/` the canonical native host for the existing profile-picker WebUI controller;
- makes `ghost://passwords/` the canonical native host for the existing password-manager WebUI controller;
- removes the former `browser_about_handler.cc` profile/password redirect aliases;
- strengthens the fork verifier so native controller/host registration is required and restoration of redirect aliases is rejected;
- expands revision-pinned source anchors to the actual 2026 profile/password controller registrations, Search fallback implementation and Windows install/executable build graph;
- requires exactly 38 product locales across product configuration and source audits;
- keeps the source-built benchmark evidence and signing gates unchanged and fail-closed;
- synchronizes the disabled update baseline at 0.1.4 without inventing package hash/size evidence.

These changes are not a production-binary or numerical performance claim until the controlled full-source compile and benchmark succeed for the exact candidate commit.

## Release gate

A production release may be published only from the exact commit that successfully completes the controlled Windows source-build pipeline.

Required gate:

1. version/component/update-baseline synchronization;
2. proprietary Ghosium license validation and required third-party legal payload;
3. builder/toolchain preflight;
4. exact source revision and transformation-anchor verification;
5. complete Ghosium source transformation;
6. public-surface/branding verification;
7. 38-locale verification;
8. canonical native `ghost://profiles/` and `ghost://passwords/` host verification;
9. Windows executable identity verification;
10. native updater verification;
11. performance-default verification;
12. deterministic Windows x64 configuration;
13. full browser compile;
14. compiled-output verification;
15. sandbox-preserving runtime smoke;
16. source-built performance measurement and `GHOSIUM-PERFORMANCE.json` validation;
17. internal technical installer verification;
18. verified source-runtime extraction/staging;
19. canonical `Ghosium-Browser-Setup.exe` build;
20. production Authenticode signing on `main`;
21. install → runtime → update → runtime → uninstall round trip;
22. profile/language preservation and cleanup verification;
23. exact update-manifest generation;
24. provenance and SHA-256 evidence;
25. immutable release publication.

A source audit, patch-only result, historical package, technical archive or installer definition does not satisfy this gate.

## Public release asset

The stable end-user Windows artifact is:

```text
Ghosium-Browser-Setup.exe
```

The workflow may retain technical source-runtime archives and JSON evidence for diagnosis/provenance, but they are not alternative end-user browser packages.

The retired legacy Portable package is not part of the active release architecture. It must not return unless a future Portable design is generated from the same verified source output and receives equivalent runtime, profile-isolation, update and cleanup verification.

## Release evidence

A successful production candidate produces or retains:

```text
Ghosium-Browser-Setup.exe
GHOSIUM-BUILDER-READY.json
GHOSIUM-SOURCE-BUILD.json
GHOSIUM-PERFORMANCE.json
GHOSIUM-UPSTREAM-MINI-INSTALLER-SMOKE.json
GHOSIUM-SOURCE-STAGE.json
GHOSIUM-PUBLIC-SETUP.json
GHOSIUM-CANONICAL-SETUP-SMOKE.json
GHOSIUM-UPDATE-MANIFEST.json
GHOSIUM-VERSION.txt
GHOSIUM-LICENSE.txt
THIRD_PARTY_NOTICES.md
SHA256SUMS.txt
```

The raw source-runtime archive can remain a workflow artifact but is not the stable public package.

## Locale gate

Browser and interactive Setup must expose the same 38-locale product set.

```text
primary/default: en-US
required: hr
```

Fresh installation can initialize the browser language from Setup. Update/reinstall must not overwrite an existing language selected by the user.

## Internal WebUI gate

The product scheme is `ghost://` with restricted surfaces under `ghost-untrusted://`.

`ghost://profiles/` must be backed by the native profile-picker controller through its canonical host constant. `ghost://passwords/` must be backed by the native password-manager controller through its canonical host constant. Production source verification rejects a return to `browser_about_handler.cc` redirects for either route.

The controller implementations remain maintained engine code; Ghosium changes the product-facing host contract rather than copying security-sensitive profile/password logic into parallel controllers.

## Performance gate

Every source-built candidate must run `scripts/benchmark-ghosium-windows.ps1` against the newly compiled `Ghosium-Browser.exe` using `-ProfileMode UserDataDir` and retain `GHOSIUM-PERFORMANCE.json`.

Required measured scenarios include:

- cold startup to first usable browser window;
- warm startup to first usable browser window;
- 1-tab, 5-tab and 10-tab process/memory samples;
- short idle CPU/I/O activity;
- a 60-second one-tab idle activity interval;
- best-effort per-process Windows GPU memory;
- best-effort Ghosium-owned TCP/UDP endpoint activity.

Unsupported GPU counters must be marked unavailable instead of reported as zero. TCP/UDP endpoint counts are not byte-level network telemetry.

The controlled builder used for the first-usable-window benchmark must have an interactive Windows desktop session. Do not weaken browser or Windows security to work around a non-interactive runner.

Performance changes must not weaken:

- sandboxing;
- GPU sandboxing;
- site/process isolation;
- TLS/certificate validation;
- extension trust;
- update hash/signature/publisher validation.

Renderer-process limits are not accepted as a synthetic RAM optimization.

## Search gate

The Ghosium Search production UI is deployed from `search-web/` and must remain:

- visually aligned with Ghosium Browser;
- responsive on desktop and mobile;
- server-rendered with reusable components;
- free of a public JavaScript runtime bundle;
- free of inline JavaScript and inline CSS;
- free of public developer/index-provider implementation details;
- independent of Node/npm/Composer at request time.

Advanced parser behavior such as `site:` and explicit `!bang` handling remains tested through the backend/API contract without being required on the public home page.

## Update and uninstall gate

The canonical Setup is the only public maintenance package and supports normal install, `/S /UPDATE` and `/S /UNINSTALL`.

Update validation requires an exact trusted Setup URL, size, SHA-256, Authenticode status, expected publisher relationship and signed Ghosium/Brendigo product metadata.

Before replacing/removing installed program files, Setup requests normal termination of the `Ghosium-Browser.exe` process tree. Forced termination is a bounded fallback.

The normal user profile remains outside the program directory and must survive update and ordinary uninstall. No standalone updater or uninstaller executable may be introduced.

## Update manifest

`updates-web/windows/stable.json` is a fail-closed repository baseline. Its version stays synchronized with `VERSION`, but `enabled` remains false and SHA-256/size remain empty/zero until generated from a real verified signed package.

On production `main`, `scripts/generate-update-manifest.ps1 -RequireAuthenticode` generates release evidence from the exact signed Setup package.

## Immutability

Never overwrite an existing Ghosium release or repoint its tag. If `ghosium-v0.x.y` already exists, publication fails and a correction requires a new version.

## Required CI contracts

Before publication, applicable hosted CI must be green, including:

- Version and Release Contract;
- Brand Surface Contract;
- Public Surface Contract;
- Locale Contract;
- Performance Defaults Contract;
- Source Patch Contract;
- Full-Source Engine Audit;
- Source Builder Contract;
- Windows Installer Contract;
- Native Update Contract;
- Canonical Release Contract;
- Search Shared Hosting Contract;
- Store Trust Audit.

Tests must not be weakened to make a release green. Fix implementation defects or update a stale assertion only when the pinned source/API genuinely changed and the replacement assertion remains at least as strict.

## Signing

Do not describe a release as Authenticode-signed unless the actual published Setup and required binaries are signed by the configured Brendigo/Ghosium identity and validation succeeds in the production workflow.

Signing keys, PFX files and passwords must never be committed.

## Legal payload

`GHOSIUM-LICENSE.txt` contains the Brendigo proprietary product license. `THIRD_PARTY_NOTICES.md` and applicable bundled license files preserve mandatory third-party rights and notices.

Required third-party attribution remains a legal requirement and must stay isolated from Ghosium product branding rather than removed or represented as Brendigo ownership.

## Release decision

Do not merge or publish 0.1.4 merely because hosted source contracts are green. The production decision requires the controlled Windows full-source compile, source-built performance evidence and runtime/installer/signing evidence for the exact production commit.
