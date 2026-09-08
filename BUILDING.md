# Building Ghosium Browser

## Current development line

The active product version is `0.1.2`. Ghosium Browser is built as a full-source Windows x64 product. A source audit, patch-only result, historical precompiled package, renamed technical installer or wrapper executable is not a production Ghosium release.

The canonical production workflow is:

```text
.github/workflows/full-source-windows-build.yml
```

It is intentionally manual and runs on the controlled `ghosium-source-builder` Windows x64 runner.

## Production build chain

The release path is fail-closed:

1. validate `VERSION`, bundled component versions and Store metadata;
2. validate Ghosium product licensing and required third-party legal payload;
3. validate the controlled Windows builder and exact `DEPOT_TOOLS_REVISION`;
4. validate revision-pinned transformation anchors;
5. bootstrap/reset the source workspace to `ENGINE_SOURCE_REVISION`;
6. apply Ghosium identity, branding, public-surface removal, localization, `ghost://` routing, Search, Store/update destinations and Windows executable identity;
7. verify the transformed source and prove Ghosium transformations did not edit `third_party/`;
8. apply/verify native performance defaults;
9. configure the reviewed Windows x64 GN arguments;
10. compile the browser and technical packaging targets from source;
11. verify the compiled Ghosium binaries and run sandbox-preserving runtime smoke tests;
12. verify the technical source-installer path as internal build evidence;
13. extract and verify the newly built runtime archive;
14. assemble the canonical Ghosium release stage;
15. on production `main`, sign `Ghosium-Browser.exe` and `Ghosium-Proxy.exe`;
16. build `Ghosium-Browser-Setup.exe` from `installer/ghosium.nsi`;
17. prove the public Setup is not a renamed technical installer;
18. on production `main`, sign the Setup and verify the publisher relationship;
19. run install → runtime → update → runtime → uninstall smoke verification;
20. verify locale/profile preservation and cleanup behavior;
21. generate the production update manifest for the exact signed Setup;
22. generate provenance and SHA-256 evidence;
23. publish a new immutable `ghosium-v0.x.y` release only if the tag does not already exist.

The repository must not claim a source-built release until this controlled chain actually succeeds for the exact commit.

## Source and toolchain pins

The deterministic source build is controlled by:

- `ENGINE_SOURCE_REVISION` — exact browser-engine source commit;
- `DEPOT_TOOLS_REVISION` — exact compatible build-tool commit;
- `engine/build/windows-x64.args.gn` — reviewed Windows x64 build arguments;
- `scripts/verify-source-builder-host.ps1` — controlled-builder preflight;
- `scripts/verify-pinned-source-anchors.py` — revision compatibility audit.

Production builds must not use floating branches, moving tags or unreviewed local source edits.

## Technical build names versus public identity

Some source-tree paths, GN/Ninja targets and runtime libraries still use implementation names required by the upstream build graph. They remain internal engineering API and are not accepted as public Ghosium product branding.

The public Windows product identity is:

```text
Ghosium-Browser.exe
Ghosium-Proxy.exe
Ghosium-Browser-Setup.exe
```

The technical source-runtime archive is retained only as workflow evidence. It is not a stable end-user release asset.

Do not globally rename an internal build target or DLL name without a coordinated migration that proves dependency resolution, process spawning, DLL loading, installer layout, sandbox/crash integration and runtime behavior.

## 38-language contract

Ghosium 0.1.2 supports 38 locales. English (`en-US`) is the primary/default language and Croatian (`hr`) is mandatory.

The browser and interactive Setup must expose the same locale set. CI verifies that contract and verifies the corresponding pinned source translation bundles before an expensive build.

A fresh install initializes the native browser locale from the Setup selection. Reinstall/update preserves an existing browser language preference.

## Performance defaults

Performance work uses native engine mechanisms and must be benchmark-driven.

The 0.1.2 Windows source configuration includes:

```text
enable_background_mode = false
```

This removes legacy background-app keep-alive behavior after the last window closes.

`scripts/rewrite-engine-performance-defaults.ps1` enables native Memory Saver by default only when a profile has not explicitly selected another state. Medium aggressiveness, existing discard timing, tab freezing, user exceptions and explicit user preferences remain unchanged.

The following are forbidden performance shortcuts:

- disabling browser or renderer sandboxing;
- disabling site/process isolation;
- bypassing TLS/certificate validation;
- disabling extension or update trust verification;
- applying a renderer-process cap solely to improve RAM numbers.

Do not publish performance claims until the compiled source-built 0.1.2 binary is measured with the same benchmark methodology as the accepted baseline.

## Native update and same-Setup maintenance

The browser-owned update endpoint is:

```text
https://updates.ghosium.com/windows/stable.json
```

The updater validates product/channel/platform/version, trusted URL, byte size, SHA-256, Authenticode publisher relationship and signed product metadata before executing the verified Setup package.

`Ghosium-Browser-Setup.exe` is the single public maintenance package and handles:

```text
normal install
/S /UPDATE
/S /UNINSTALL
```

No separately distributed updater or uninstaller executable is part of the Ghosium product.

Update/uninstall first requests normal shutdown of the `Ghosium-Browser.exe` process tree. Forced termination is retained only as a maintenance fallback. The user profile lives outside the install directory and is preserved by normal update/uninstall.

The checked-in `updates-web/windows/stable.json` remains disabled. Enabled production metadata is generated only from a verified signed canonical Setup.

## Production signing

Production `main` requires:

- `GHOSIUM_SIGN_CERT_THUMBPRINT` in GitHub Actions secrets;
- `GHOSIUM_TIMESTAMP_URL` in GitHub Actions variables;
- an accessible code-signing private key for the controlled runner;
- the required Windows SDK `signtool.exe`.

The signing process uses SHA-256 file digests and RFC3161 timestamping. Browser, proxy and Setup signatures must validate and use the expected publisher relationship.

Never commit a PFX, private key, password or other signing secret.

## Windows builder

The full-source workflow targets:

```text
self-hosted
Windows
X64
ghosium-source-builder
```

The builder must pass `scripts/verify-source-builder-host.ps1`. Detailed provisioning is maintained in `docs/SOURCE_BUILDER_SETUP.md`.

A constrained or misconfigured host must fail preflight; do not weaken checks to make a machine appear build-ready.

## Local controlled build

Use repository scripts rather than ad-hoc source edits:

```powershell
./scripts/verify-source-builder-host.ps1
./scripts/bootstrap-engine-source.ps1 -Destination <work-root>
./scripts/apply-engine-branding.ps1 -SourceRoot <work-root>\src
./scripts/verify-engine-fork.ps1 -SourceRoot <work-root>\src
./scripts/verify-engine-windows-executable.ps1 -SourceRoot <work-root>\src
./scripts/verify-engine-version-updater.ps1 -SourceRoot <work-root>\src
./scripts/configure-engine-build.ps1 -SourceRoot <work-root>\src -OutDir out/Ghosium
```

The pinned build graph currently requires the technical targets:

```powershell
autoninja -C out/Ghosium chrome mini_installer
```

Those target names are internal build API. After compilation, run the same compiled-output verification, staging, Setup packaging and maintenance smoke sequence used by the production workflow.

## Release evidence

The controlled build produces evidence including:

```text
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

The raw source-runtime archive may be retained as an internal workflow artifact for diagnosis/provenance, but it is not the stable end-user release.

## Benchmarking

Use `scripts/benchmark-ghosium-windows.ps1` for comparable Windows measurements. The benchmark records startup, first usable window, memory, process count, handles, CPU, disk transfer counters and idle behavior.

A metric not reliably collected by the harness must not be represented as measured. GPU-memory and precise per-process network-byte attribution remain separate work until reliable collectors are implemented.

## Legal and security requirements

Brendigo-authored proprietary portions are governed by the Brendigo Proprietary Commercial Software License Agreement in `LICENSE` unless a separate written license states otherwise.

Required third-party licenses, copyright notices and attribution must remain intact in their legal context. They are not Ghosium product branding and must not be rewritten as Brendigo ownership.

Security boundaries take priority over synthetic performance numbers.
