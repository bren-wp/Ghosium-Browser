# Ghosium Production Release Procedure

## Current product version

The active development version is `0.1.2`.

Version policy:

- `0.x.0` — meaningful product/security/performance milestone;
- `0.x.y` — smaller production correction.

Every production PR must advance `VERSION`. The bundled Ghosium Privacy manifest, Ghosium Search manifest and built-in Store catalog versions must match it exactly.

New releases use the immutable namespace:

```text
ghosium-v0.1.0
ghosium-v0.1.1
ghosium-v0.1.2
ghosium-v0.2.0
```

Historical release tags are left untouched.

## 0.1.2 release scope

The 0.1.2 line includes:

- 38 supported product/Setup locales;
- English (`en-US`) as primary/default language;
- Croatian (`hr`) as required/selectable language;
- removal of the retired wrapper-launcher and legacy Portable packaging path;
- direct source-built Ghosium Windows executable identity;
- native Memory Saver enabled by default for profiles without an explicit choice;
- legacy background-app keep-alive disabled on Windows;
- canonical Setup shutdown logic that prefers normal browser close before forced fallback;
- synchronized disabled update baseline for 0.1.2;
- stricter source-anchor, localization and performance-default contracts.

These source changes are not a performance or production-binary claim until the controlled full-source compile succeeds.

## Release gate

A production release may be published only from the exact commit that successfully completes the controlled Windows source-build pipeline.

Required gate:

1. version/component synchronization;
2. proprietary Ghosium license validation and required third-party legal payload;
3. builder/toolchain preflight;
4. exact source revision and transformation-anchor verification;
5. complete Ghosium source transformation;
6. public-surface/branding verification;
7. 38-locale verification;
8. Windows executable identity verification;
9. native updater verification;
10. performance-default verification;
11. deterministic Windows x64 configuration;
12. full browser compile;
13. compiled-output verification;
14. sandbox-preserving runtime smoke;
15. internal technical installer verification;
16. verified source-runtime extraction/staging;
17. canonical `Ghosium-Browser-Setup.exe` build;
18. production Authenticode signing on `main`;
19. install → runtime → update → runtime → uninstall round trip;
20. profile/language preservation and cleanup verification;
21. exact update-manifest generation;
22. provenance and SHA-256 evidence;
23. immutable release publication.

A source audit, patch-only result, historical package, technical archive or installer definition does not satisfy this gate.

## Public release asset

The stable end-user Windows artifact is:

```text
Ghosium-Browser-Setup.exe
```

The release process may retain diagnostic/provenance evidence in GitHub Actions, including the technical source-runtime archive and JSON reports, but those are not advertised as alternative end-user browser packages.

The retired legacy Portable package is not part of the 0.1.2 release architecture. It must not return unless a new Portable design is built from the same verified source output and receives equivalent runtime, profile-isolation and cleanup verification.

## Release evidence

The controlled workflow produces or retains:

```text
Ghosium-Browser-Setup.exe
GHOSIUM-BUILDER-READY.json
GHOSIUM-SOURCE-BUILD.json
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

The raw source-runtime archive can remain a workflow artifact for provenance/debugging but is not the stable public browser package.

## Locale gate

The release must expose the same 38-locale set in browser and Setup.

Required language invariants:

```text
primary/default: en-US
required: hr
```

A fresh installation may initialize the browser language from Setup. Update/reinstall must not overwrite a language already selected by the user in Ghosium Settings.

## Performance gate

0.1.2 changes native resource defaults but does not claim an improvement until the compiled source-built binary is benchmarked.

For any startup/RAM/CPU/shutdown claim, retain comparable evidence from `scripts/benchmark-ghosium-windows.ps1`.

Performance changes must not weaken:

- sandboxing;
- site/process isolation;
- TLS/certificate validation;
- extension trust;
- update hash/signature/publisher validation.

Renderer-process limits are not accepted as a synthetic RAM optimization.

## Update and uninstall gate

The canonical Setup is the only public maintenance package. It supports:

```text
normal install
/S /UPDATE
/S /UNINSTALL
```

Update validation requires an exact trusted Setup URL, size, SHA-256, Authenticode status, expected publisher relationship and signed Ghosium/Brendigo product metadata.

Before replacing/removing installed program files, Setup requests normal termination of the `Ghosium-Browser.exe` process tree. Forced termination is a bounded fallback.

The normal user profile remains outside the program directory and must survive update and ordinary uninstall.

No standalone updater or uninstaller executable may be introduced.

## Update manifest

The repository baseline:

```text
updates-web/windows/stable.json
```

must remain disabled/fail-closed. Its version must stay synchronized with `VERSION`, but it must have no production package hash or size until generated from a verified release artifact.

On production `main`, `scripts/generate-update-manifest.ps1 -RequireAuthenticode` generates the enabled update evidence from the exact signed Setup package.

## Immutability

Never overwrite an existing Ghosium release or repoint its tag.

If `ghosium-v0.x.y` already exists, the release must fail. A correction requires a new version.

## Required CI contracts

Before publication, applicable CI must be green, including:

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

Tests must not be weakened to make a release green. Fix the implementation or update a stale assertion only when the pinned source/API contract genuinely changed and the replacement assertion is at least as strict.

## Signing

Do not describe a release as Authenticode-signed unless the actual published Setup and required binaries are signed by the configured Brendigo/Ghosium identity and validation succeeds in the production workflow.

Signing keys, PFX files and passwords must never be committed.

## Legal payload

`GHOSIUM-LICENSE.txt` contains the Brendigo proprietary product license. `THIRD_PARTY_NOTICES.md` and applicable bundled license files preserve mandatory third-party rights and notices.

Required third-party attribution is a legal requirement and must remain isolated from Ghosium product branding rather than removed or represented as Brendigo ownership.

## Release decision

Do not merge/publish 0.1.2 merely because hosted source contracts are green. The production decision requires the controlled Windows full-source compile and runtime/installer evidence for the exact production commit.
