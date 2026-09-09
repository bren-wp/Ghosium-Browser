# Ghosium Production Release Procedure

## Current product version

The active development version is `0.1.12`.

Version policy:

- `0.x.0` — meaningful product/security/performance milestone;
- `0.x.y` — production correction or bounded product improvement.

Every production PR must advance `VERSION`. Ghosium Privacy, built-in Store metadata and the disabled Windows update baseline must remain synchronized.

New releases use the immutable namespace:

```text
ghosium-v0.1.0
ghosium-v0.1.1
ghosium-v0.1.2
ghosium-v0.1.3
ghosium-v0.1.4
ghosium-v0.1.5
ghosium-v0.1.6
ghosium-v0.1.7
ghosium-v0.1.8
ghosium-v0.1.9
ghosium-v0.1.10
ghosium-v0.1.11
ghosium-v0.1.12
ghosium-v0.2.0
```

Historical releases remain untouched.

## 0.1.12 release scope

The 0.1.12 line is a native product-branding, privacy, stability and low-overhead hardening release built on the pinned Chromium source architecture:

- the native New Tab must render the canonical local Ghosium mark and must not depend on an optional extension for core product identity;
- the stock rendered Google logo, OneGoogleBar, remote Doodle initialization, animated Doodles/murals, Microsoft/provider modules, AI/Composebox/Threads entry points, Lens/voice entry points, action chips and browser promos are disabled on the Ghosium-owned New Tab;
- NTP prefetch/prerender triggers are disabled to remove unnecessary speculative work while normal browsing and the omnibox remain intact;
- local shortcuts and local customization remain available;
- Ghosium-owned New Tab copy remains provider-neutral while the actual external Google Search routing remains truthful and direct;
- third-party cookies are blocked by default for new/default profiles;
- search suggestions, speculative network prediction/preloading and remote alternate-error pages are disabled by default;
- online spelling-service upload is required to remain disabled by default;
- native Memory Saver and background-app shutdown defaults remain in force;
- Safe Browsing, TLS/certificate validation, browser/renderer/GPU sandboxing, site/process isolation, extension trust and update verification must remain intact;
- all new native source transforms are revision-pinned, fail on anchor drift and are verified before GN generation;
- no Ghosium transform may edit `third_party/` source;
- candidate verification remains fail-closed on pinned source/build-tool revisions, source anchors, complete compile/runtime/performance/installer/provenance gates and the canonical Setup/Portable packaging contract;
- production `main` remains on the controlled `self-hosted / Windows / X64 / ghosium-source-builder` runner and retains the Authenticode private-key boundary;
- the checked-in 0.1.12 update baseline remains fail-closed with `enabled:false`, empty SHA-256 and zero size until a real verified signed Setup exists.

This scope is not a production-binary, signing or performance claim. Canonical release status still requires successful full-source candidate evidence and the separately required controlled production compile, runtime, performance, installer, signing and provenance gates for the exact production tree.

## Candidate before production

A release candidate must be validated before production publication.

Candidate sequence:

1. merge the reviewed versioned 0.1.12 development change to `main` only after applicable static/pinned-source contracts are green;
2. create/update `ghosium/release/<VERSION>` from the exact intended current `main` release base;
3. keep exactly one `.release/ghosium-v<VERSION>.request` marker as the sole release-branch delta;
4. pushing that marker from the exact release branch dispatches the controlled full-source Windows candidate build;
5. complete candidate source bootstrap, native transform, GN, compile, runtime, installer and performance gates for the exact candidate SHA;
6. open the release-marker-only PR to `main`;
7. require Version/Release and Release Marker Promotion contracts to verify the exact branch, marker and successful candidate evidence bundle;
8. if `main` moves, refresh the candidate from current `main` and rebuild rather than using stale evidence;
9. merge only the exact reviewed marker state intended for production;
10. explicitly dispatch the production `main` full-source workflow;
11. require production signing, canonical Setup/Portable verification, update-manifest generation and immutable release publication.

A candidate marker merged into `main` is inert by design. It must not independently dispatch production.

## Release gate

A production release may be published only from the exact commit that successfully completes the controlled Windows source-build pipeline.

Required gate:

1. version/component/update-baseline synchronization;
2. proprietary Ghosium license validation and required third-party legal payload;
3. builder/toolchain preflight;
4. exact Chromium source revision and transformation-anchor verification;
5. complete Ghosium source transformation and public identity verification;
6. native `ghost://` / `ghost-untrusted://` route verification;
7. native New Tab Ghosium mark verification and remote Doodle/cloud/promo path removal;
8. native privacy-default verification;
9. 38-locale verification;
10. canonical native `ghost://profiles/` and `ghost://passwords/` host verification;
11. Windows executable identity verification;
12. native updater verification;
13. external Google Search fallback/routing contract verification without fake Ghosium Search branding;
14. performance-default verification;
15. deterministic Windows x64 configuration;
16. full browser compile;
17. compiled-output verification;
18. sandbox-preserving runtime smoke;
19. source-built performance measurement and `GHOSIUM-PERFORMANCE.json` validation;
20. internal technical installer verification;
21. verified source-runtime extraction/staging;
22. canonical `Ghosium-Browser-Setup.exe` and `Ghosium-Browser-Portable.exe` build from the same verified source stage;
23. Portable registry-free/profile-isolation provenance validation;
24. production Authenticode signing of required binaries, Setup and Portable on `main`;
25. install → runtime → update → runtime → uninstall round trip for Setup;
26. profile/language preservation and cleanup verification;
27. exact update-manifest generation for the signed Setup;
28. provenance and SHA-256 evidence for both public packages;
29. immutable release publication.

A source audit, patch-only result, historical package, technical archive or installer definition does not satisfy this gate.

## Public release assets

The stable end-user Windows artifacts are:

```text
Ghosium-Browser-Setup.exe
Ghosium-Browser-Portable.exe
```

Setup is the canonical install/update/uninstall maintenance package. Portable is generated from the same verified source stage, writes no install registration/shortcuts, and uses an adjacent isolated user-data directory. Technical source-runtime archives and JSON evidence may be retained for diagnosis/provenance but are not alternative end-user browser packages.

The retired legacy wrapper/snapshot Portable architecture remains forbidden.

## Release evidence

A successful production candidate produces or retains:

```text
Ghosium-Browser-Setup.exe
Ghosium-Browser-Portable.exe
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

The Release Marker Promotion Contract must verify the candidate artifact for the exact marker PR head SHA before that marker can be promoted. Candidate proof does not replace the separately required signed production `main` build.

## Locale gate

Browser and interactive Setup must expose the same 38-locale product set.

```text
primary/default: en-US
required: hr
```

Fresh installation can initialize the browser language from Setup. Update/reinstall must not overwrite an existing language selected by the user.

## Native WebUI and branding gate

The product scheme is `ghost://` with restricted surfaces under `ghost-untrusted://`.

`ghost://profiles/` must be backed by the native profile-picker controller through its canonical host constant. `ghost://passwords/` must be backed by the native password-manager controller through its canonical host constant. Production source verification rejects a return to `browser_about_handler.cc` redirects for either route.

The native New Tab must use the canonical Ghosium mark. A technical upstream asset filename may remain where required by the build graph, but byte-hash verification must prove that the rendered asset is the Ghosium mark. Remote Doodle initialization and provider-owned NTP cloud/promo modules must remain disabled.

Required third-party copyright/license attribution is legal material and must not be rewritten as Brendigo ownership.

## Privacy and security gate

The exact pinned source transform must prove all of the following defaults:

- `CookieControlsMode::kBlockThirdParty`;
- search suggestions disabled;
- network prediction/preloading disabled;
- remote alternate-error pages disabled;
- online spelling-service upload disabled.

These defaults do not authorize weakening Safe Browsing, sandboxing, GPU sandboxing, site/process isolation, TLS/certificate validation, extension trust, update verification or Windows exploit mitigations. A performance or privacy change that disables those protections is rejected.

## Performance gate

Every source-built candidate must run `scripts/benchmark-ghosium-windows.ps1` against the newly compiled `Ghosium-Browser.exe` using `-ProfileMode UserDataDir` and retain `GHOSIUM-PERFORMANCE.json`.

Required measured scenarios include cold/warm startup, 1/5/10-tab process/memory samples, short and 60-second idle activity, best-effort per-process Windows GPU memory and best-effort Ghosium-owned TCP/UDP endpoint activity.

Unsupported GPU counters must be marked unavailable instead of reported as zero. TCP/UDP endpoint counts are not byte-level network telemetry.

The controlled builder used for first-usable-window measurements must have an interactive Windows desktop session. Do not weaken browser or Windows security to work around a non-interactive runner.

Renderer-process limits are not accepted as a synthetic RAM optimization. No numerical 0.1.12 performance claim is valid until the exact compiled candidate produces comparable evidence.

## Search gate

Ghosium Browser does not publish or bundle a first-party web search service. The release candidate must preserve all of the following:

- the pinned engine's reviewed Google fallback remains intact;
- New Tab submits `q` directly to `https://www.google.com/search`;
- Ghosium-owned New Tab text may remain neutral (`Search the web`) rather than carrying Google product branding;
- no Ghosium-owned default-search provider is injected into engine source;
- explicit user search-engine choices, enterprise policy and extension overrides retain native precedence;
- no first-party Search server/deployment payload is packaged or published;
- external provider identity must never be falsely represented as a Ghosium-operated privacy service.

## Repository hygiene gate

The repository hygiene workflow must remain green and fail closed if any of these return:

- `search-provider/`;
- `search-web/`;
- retired Search-only CI/migration files;
- legacy snapshot-based stable release workflow;
- stale fixed-version candidate dispatch paths;
- fake `Ghosium Search` branding or `search.ghosium.com` routing;
- a checked-in stable update manifest that is enabled or contains a package hash/size before verified production generation;
- loss of canonical source-build signing, main-only publication, provenance or SHA-256 invariants.

## Update and uninstall gate

The canonical Setup is the only public maintenance package and supports normal install, `/S /UPDATE` and `/S /UNINSTALL`. Portable is a separate registry-free run-in-place package and is never used as the updater/uninstaller.

Update validation requires an exact trusted Setup URL, size, SHA-256, Authenticode status, expected publisher relationship and signed Ghosium/Brendigo product metadata.

Before replacing/removing installed program files, Setup requests normal termination of the `Ghosium-Browser.exe` process tree. Forced termination is a bounded fallback.

The normal user profile remains outside the program directory and must survive update and ordinary uninstall. No standalone updater or uninstaller executable may be introduced.

## Update manifest

`updates-web/windows/stable.json` is a fail-closed repository baseline. Its version stays synchronized with `VERSION`, but `enabled` remains false and SHA-256/size remain empty/zero until generated from a real verified signed package.

On production `main`, `scripts/generate-update-manifest.ps1 -RequireAuthenticode` generates release evidence from the exact signed Setup package.

## Immutability

Never overwrite an existing Ghosium release or repoint its tag. If `ghosium-v0.x.y` already exists, publication fails and a correction requires a new version.

## Required CI contracts

Before candidate merge and publication, applicable hosted CI must be green, including:

- Version and Release Contract;
- Repository Hygiene Contract;
- Ghosium Native UI and Privacy Contract;
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
- Store Trust Audit;
- Release Marker Promotion Contract for marker-only promotion PRs.

Tests must not be weakened to make a release green. Fix implementation defects or update a stale assertion only when the intended product/security contract changed deliberately and the replacement assertion remains strict.

## Signing

Do not describe a release as Authenticode-signed unless the actual published Setup, Portable and required binaries are signed by the configured Brendigo/Ghosium identity and validation succeeds in the production workflow.

Signing keys, PFX files and passwords must never be committed.

## Legal payload

`GHOSIUM-LICENSE.txt` contains the Brendigo proprietary product license. `THIRD_PARTY_NOTICES.md` and applicable bundled license files preserve mandatory third-party rights and notices.

Required third-party attribution remains a legal requirement and must stay isolated from Ghosium product branding rather than removed or represented as Brendigo ownership.

## Release decision

Do not merge or publish 0.1.12 merely because hosted source contracts are green. Development merge requires the reviewed 0.1.12 contracts to pass; release-marker promotion additionally requires successful controlled Windows full-source candidate evidence for the exact candidate SHA. Publication requires the production `main` source compile, source-built performance evidence, runtime/installer evidence, valid signing, exact update-manifest binding and immutable release publication for the exact production commit.
