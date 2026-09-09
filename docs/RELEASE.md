# Ghosium Production Release Procedure

## Current product version

The active development version is `0.1.10`.

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
ghosium-v0.2.0
```

Historical releases remain untouched.

## 0.1.10 release scope

The 0.1.10 line carries forward the 0.1.9 Ghosium UI, canonical Setup/Portable packaging, fail-closed Google Search and release contracts while hardening GitHub-hosted source-builder parity and Windows toolchain verification:

- Chromium helpers `fetch`, `gclient`, `gn` and `autoninja` must resolve from the exact pinned `depot_tools` checkout;
- 64-bit Python 3 is verified independently because the pinned `depot_tools` revision does not provide its own `python3` wrapper;
- Windows SDK, Visual Studio/ATL/MFC and Debugging Tools requirements are centralized in `engine/build/windows-toolchain.json` and validated semantically by CI;
- GitHub-hosted source-builder parity remains fail-closed on the exact toolchain, pinned source/build-tool revisions, NTFS workspace and required free-space contract;
- parity probes are serialized so stale hosted runs do not compete for Windows capacity or obscure the newest evidence;
- no production workflow migration from the controlled source builder is permitted until hosted parity is fully green and the complete compile/runtime/performance/installer/signing/update/release contract can be preserved;
- Google Search remains the default external web search service and no Ghosium-owned web search backend or bundled default-search provider is part of the product;
- canonical source packaging continues to produce both `Ghosium-Browser-Setup.exe` and registry-free `Ghosium-Browser-Portable.exe` from the same verified source stage;
- production publication continues to require exact SHA-256/size provenance and Valid Authenticode for public packages and required binaries;
- the checked-in 0.1.10 update baseline remains fail-closed with `enabled:false`, empty SHA-256 and zero size until a real verified signed Setup exists.

This scope is not a production-binary, signing or performance claim. Canonical release status still requires the controlled full-source candidate/production compile, runtime, performance, installer, signing and provenance gates for the exact release tree.

## Candidate before production

A release candidate must be validated before production publication.

Candidate sequence:

1. create/update `ghosium/release/<VERSION>` from the exact intended release base;
2. synchronize `VERSION`, bundled component versions, Store metadata and disabled update baseline;
3. keep exactly one `.release/ghosium-v<VERSION>.request` marker;
4. pushing that marker from the exact release branch dispatches the controlled full-source Windows candidate build;
5. complete the candidate compile, runtime, installer and performance gates for the exact candidate SHA;
6. open the release-marker-only PR to `main`;
7. require Version/Release and Release Marker Promotion contracts to verify the exact branch, marker and successful candidate evidence bundle;
8. merge only the exact reviewed candidate tree/marker state intended for production;
9. explicitly dispatch the production `main` full-source workflow;
10. require production signing, canonical Setup verification, update-manifest generation and immutable release publication.

A candidate marker merged into `main` is inert by design. It must not independently dispatch production.

If `main` changes after candidate evidence is produced, the candidate is stale unless exact source-tree equivalence is independently proven. Do not publish an older candidate merely because its hosted checks were green.

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
11. Google Search/default-search contract verification;
12. performance-default verification;
13. deterministic Windows x64 configuration;
14. full browser compile;
15. compiled-output verification;
16. sandbox-preserving runtime smoke;
17. source-built performance measurement and `GHOSIUM-PERFORMANCE.json` validation;
18. internal technical installer verification;
19. verified source-runtime extraction/staging;
20. canonical `Ghosium-Browser-Setup.exe` and `Ghosium-Browser-Portable.exe` build from the same verified source stage;
21. Portable registry-free/profile-isolation provenance validation;
22. production Authenticode signing of Setup and Portable on `main`;
23. install → runtime → update → runtime → uninstall round trip for Setup;
24. profile/language preservation and cleanup verification;
25. exact update-manifest generation for the signed Setup;
26. provenance and SHA-256 evidence for both public packages;
27. immutable release publication.

A source audit, patch-only result, historical package, technical archive or installer definition does not satisfy this gate.

## Public release asset

The stable end-user Windows artifacts are:

```text
Ghosium-Browser-Setup.exe
Ghosium-Browser-Portable.exe
```

Setup is the canonical install/update/uninstall maintenance package. Portable is generated from the same verified source stage, writes no install registration/shortcuts, and uses an adjacent isolated user-data directory. The workflow may retain technical source-runtime archives and JSON evidence for diagnosis/provenance, but they are not alternative end-user browser packages.

The retired legacy wrapper/snapshot Portable architecture remains forbidden; the current Portable design is part of the canonical source-stage packaging contract and must satisfy provenance, signing and profile-isolation gates.

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

The raw source-runtime archive can remain a workflow artifact but is not the stable public package.

The Release Marker Promotion Contract must verify the candidate artifact for the exact marker PR head SHA before that marker can be promoted. This candidate proof does not replace the separately required signed production `main` build.

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

Ghosium Browser does not publish or bundle a first-party web search service. The release candidate must preserve all of the following:

- the pinned engine's reviewed Google fallback remains intact;
- New Tab submits `q` directly to `https://www.google.com/search`;
- no Ghosium-owned default-search provider is injected into engine source;
- explicit user search-engine choices, enterprise policy and extension overrides retain native precedence;
- no first-party Search server/deployment payload is packaged or published;
- Google Search is described as an external service rather than a Ghosium privacy service.

## Repository hygiene gate

The repository hygiene workflow must remain green and fail closed if any of these return:

- `search-provider/`;
- `search-web/`;
- retired Search-only CI/migration files;
- legacy snapshot-based stable release workflow;
- stale fixed-version candidate dispatch paths;
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
- Release Marker Promotion Contract for marker-only promotion PRs;
- Repository Hygiene Contract;
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
- Store Trust Audit.

The retired Search Shared Hosting Contract is not part of the current product because the first-party Search service was removed.

Tests must not be weakened to make a release green. Fix implementation defects or update a stale assertion only when the pinned source/API genuinely changed and the replacement assertion remains at least as strict.

## Signing

Do not describe a release as Authenticode-signed unless the actual published Setup, Portable and required binaries are signed by the configured Brendigo/Ghosium identity and validation succeeds in the production workflow.

Signing keys, PFX files and passwords must never be committed.

## Legal payload

`GHOSIUM-LICENSE.txt` contains the Brendigo proprietary product license. `THIRD_PARTY_NOTICES.md` and applicable bundled license files preserve mandatory third-party rights and notices.

Required third-party attribution remains a legal requirement and must stay isolated from Ghosium product branding rather than removed or represented as Brendigo ownership.

## Release decision

Do not merge or publish 0.1.10 merely because hosted source contracts are green. Marker promotion requires successful controlled Windows full-source candidate evidence for the exact candidate SHA. Publication additionally requires the production `main` source compile, source-built performance evidence, runtime/installer evidence, valid signing, exact update-manifest binding and immutable release publication for the exact production commit.
