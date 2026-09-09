# Building Ghosium Browser

## Current development line

The active product version is `0.1.12`. Ghosium Browser is built as a full-source Windows x64 product. A source audit, patch-only result, historical precompiled package, renamed technical installer or wrapper executable is not a production Ghosium release.

The canonical production workflow is:

```text
.github/workflows/full-source-windows-build.yml
```

It is intentionally manual. Release-candidate dispatches may run on a freshly provisioned GitHub-hosted `windows-2025` runner only after that runner satisfies the same pinned production source-builder preflight. Production `main` remains on the controlled `ghosium-source-builder` Windows x64 runner so the existing Authenticode private-key boundary is preserved.

## Release-candidate ordering

Release candidates use a dedicated branch named exactly `ghosium/release/<VERSION>`. The matching `.release/ghosium-v<VERSION>.request` marker may dispatch the controlled full-source **candidate** workflow only from that version-bound branch.

A same-version marker PR is valid only when it changes exactly that one marker from the exact release branch. The release-marker promotion contract then requires a completed/success full-source candidate run for the exact PR head SHA and verifies the candidate evidence bundle before promotion.

Merging a candidate marker into `main` must not automatically dispatch production. Production is a separate explicit gate performed only after the candidate has produced successful full-source/runtime/performance evidence and the exact intended candidate tree is on `main`.

## Production build chain

The release path is fail-closed:

1. validate `VERSION`, bundled component versions and Store metadata;
2. validate Ghosium product licensing and required third-party legal payload;
3. provision a non-main hosted candidate builder when applicable, then validate the Windows builder and exact `DEPOT_TOOLS_REVISION` with the same production preflight;
4. validate revision-pinned transformation anchors;
5. bootstrap/reset the source workspace to `ENGINE_SOURCE_REVISION`;
6. apply Ghosium identity, branding, public-surface removal, localization, product version, native `ghost://` routing, external Google Search fallback preservation, Store/update destinations and Windows executable identity;
7. verify the transformed source, including canonical native profile/password WebUI hosts, and prove Ghosium transformations did not edit `third_party/`;
8. apply/verify the native Ghosium New Tab hardening: local product mark, no remote Doodle initialization, provider cloud/promotional modules disabled and local shortcuts/customization preserved;
9. apply/verify privacy-strong native defaults for third-party cookies, suggestions, speculative network prediction/preloading, alternate-error pages and online spelling-service upload;
10. apply/verify native performance defaults;
11. configure the reviewed Windows x64 GN arguments;
12. compile the browser and technical packaging targets from source;
13. verify the compiled Ghosium binaries and run sandbox-preserving runtime smoke tests;
14. benchmark the newly compiled runtime and require `GHOSIUM-PERFORMANCE.json`;
15. verify the technical source-installer path as internal build evidence;
16. extract and verify the newly built runtime archive;
17. assemble the canonical Ghosium release stage;
18. on production `main`, sign `Ghosium-Browser.exe` and `Ghosium-Proxy.exe`;
19. build `Ghosium-Browser-Setup.exe` and `Ghosium-Browser-Portable.exe` from the same verified source stage;
20. prove the public Setup is not a renamed technical installer and validate the Portable registry-free/profile-isolation contract;
21. on production `main`, sign both public packages and verify their publisher relationship to the signed browser;
22. run install → runtime → update → runtime → uninstall smoke verification for Setup;
23. verify locale/profile preservation, Portable profile isolation and cleanup behavior;
24. generate the production update manifest for the exact signed Setup;
25. generate provenance, performance and SHA-256 evidence including both public packages;
26. publish a new immutable `ghosium-v0.x.y` release with Setup and Portable only if the tag does not already exist.

The repository must not claim a source-built release until this controlled chain actually succeeds for the exact commit.

## Source and toolchain pins

The deterministic source build is controlled by:

- `ENGINE_SOURCE_REVISION` — exact browser-engine source commit;
- `DEPOT_TOOLS_REVISION` — exact compatible build-tool commit;
- `engine/build/windows-toolchain.json` — required Visual Studio, Windows SDK and Debugging Tools contract;
- `engine/build/windows-x64.args.gn` — reviewed Windows x64 build arguments;
- `scripts/provision-github-hosted-source-builder.ps1` — deterministic non-main hosted candidate provisioning;
- `scripts/verify-source-builder-host.ps1` — common controlled-builder preflight;
- `scripts/verify-pinned-source-anchors.py` — revision compatibility audit.

Production builds must not use floating branches, moving tags or unreviewed local source edits.

## Technical build names versus public identity

Some source-tree paths, GN/Ninja targets and runtime libraries still use implementation names required by the upstream build graph. They remain internal engineering API and are not accepted as public Ghosium product branding.

The public Windows product identity is:

```text
Ghosium-Browser.exe
Ghosium-Proxy.exe
Ghosium-Browser-Setup.exe
Ghosium-Browser-Portable.exe
```

The technical source-runtime archive is retained only as workflow evidence. It is not a stable end-user release asset.

Do not globally rename an internal build target or DLL name without a coordinated migration that proves dependency resolution, process spawning, DLL loading, installer layout, sandbox/crash integration and runtime behavior.

## Native internal WebUI hosts

The product namespace is `ghost://` / `ghost-untrusted://`.

`ghost://profiles/` is bound to the existing native profile-picker controller by changing the canonical host constant used by its WebUI config and data source. `ghost://passwords/` is bound the same way to the native password-manager controller. The source transform removes the old `browser_about_handler.cc` redirect aliases, and `verify-engine-fork.ps1` rejects their return.

This preserves the maintained profile/password implementations while making the Ghosium URLs canonical product hosts instead of redirect shims.

## Native New Tab contract

`scripts/harden-native-new-tab.ps1` and `scripts/verify-native-new-tab.ps1` operate only on the exact pinned source revision. Before GN generation they require the native New Tab to use the canonical Ghosium mark and disable provider-owned NTP cloud/promo paths that are not required for normal browsing.

The transform disables OneGoogleBar, remote Doodle initialization, animated Doodles/murals, Microsoft/provider modules, AI/Composebox/Threads entry points, Lens/voice entry points, action chips, browser promos and NTP prefetch/prerender triggers. Local shortcuts, local customization and the normal omnibox/search flow remain available.

The upstream technical filename used by the source graph may remain `google_logo.svg`; verifier hash equality proves that its shipped bytes are the canonical Ghosium mark. Internal filenames are not accepted as public product branding.

## Native privacy-default contract

`scripts/harden-privacy-defaults.ps1` and `scripts/verify-privacy-defaults.ps1` use Chromium's own preference registration machinery. New/default profiles start with third-party cookies blocked, search suggestions disabled, network prediction/preloading disabled and remote alternate-error pages disabled. The verifier also requires online spelling-service upload to remain disabled by default.

These defaults remain user/policy controllable where Chromium supports that behavior. The hardening does not disable Safe Browsing, TLS/certificate validation, browser/renderer/GPU sandboxing, site/process isolation, extension trust or update verification.

## 38-language contract

Ghosium 0.1.12 supports 38 locales. English (`en-US`) is the primary/default language and Croatian (`hr`) is mandatory.

The browser and interactive Setup must expose the same locale set. CI verifies that contract and verifies the corresponding pinned source translation bundles before an expensive build.

A fresh install initializes the native browser locale from the Setup selection. Reinstall/update preserves an existing browser language preference.

## External Search contract

Ghosium does not ship a first-party web search backend or bundled Ghosium Search provider. New Tab submits the standard `q` parameter directly to `https://www.google.com/search`.

Ghosium-owned New Tab copy is product-neutral rather than provider-branded. The source transformation preserves the pinned engine's reviewed Google fallback and must not inject a Ghosium-owned default-search provider. Explicit user search-engine choices, enterprise policy and extension overrides keep their native precedence.

The repository hygiene contract rejects restoration of `search-provider/`, `search-web/`, the retired Search CI/deployment paths or legacy snapshot stable-release workflow.

## Performance defaults and evidence

Performance work uses native engine mechanisms and must be benchmark-driven.

The 0.1.12 Windows source configuration includes:

```text
enable_background_mode = false
```

This removes legacy background-app keep-alive behavior after the last window closes.

`scripts/rewrite-engine-performance-defaults.ps1` enables native Memory Saver by default only when a profile has not explicitly selected another state. Medium aggressiveness, existing discard timing, tab freezing, user exceptions and explicit user preferences remain unchanged.

0.1.12 additionally reduces unnecessary NTP background work by removing remote Doodle initialization, provider cloud modules and NTP speculative prefetch/prerender triggers. No numerical benefit is claimed until the compiled binary is measured.

The following are forbidden performance shortcuts:

- disabling browser or renderer sandboxing;
- disabling GPU sandboxing;
- disabling site/process isolation;
- bypassing TLS/certificate validation;
- disabling extension or update trust verification;
- applying a renderer-process cap solely to improve RAM numbers.

Do not publish performance claims until the compiled source-built 0.1.12 binary is measured with the same benchmark methodology as the accepted baseline.

The full-source workflow requires `GHOSIUM-PERFORMANCE.json` from the newly compiled runtime. Benchmark schema v2 records cold/warm first-usable-window startup, memory, process count, handles, CPU, process I/O, 1/5/10-tab scenarios, 60-second idle activity, best-effort per-process GPU memory and Ghosium-owned TCP/UDP endpoint activity. Unsupported GPU telemetry is reported as unavailable rather than as zero. Endpoint counts are not represented as byte-level network attribution.

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

No separately distributed updater or uninstaller executable is part of the Ghosium product. `Ghosium-Browser-Portable.exe` is a separate registry-free end-user package; it is not an updater or uninstaller and keeps its profile/runtime data beside the Portable executable.

Update/uninstall first requests normal shutdown of the `Ghosium-Browser.exe` process tree. Forced termination is retained only as a maintenance fallback. The user profile lives outside the install directory and is preserved by normal update/uninstall.

The checked-in `updates-web/windows/stable.json` remains disabled, version-synchronized, with empty SHA-256 and zero size. Enabled production metadata is generated only from a verified signed canonical Setup.

## Production signing

Production `main` requires:

- `GHOSIUM_SIGN_CERT_THUMBPRINT` in GitHub Actions secrets;
- `GHOSIUM_TIMESTAMP_URL` in GitHub Actions variables;
- an accessible code-signing private key for the controlled runner;
- the required Windows SDK `signtool.exe`.

The signing process uses SHA-256 file digests and RFC3161 timestamping. Browser, proxy, Setup and Portable signatures must validate and use the expected publisher relationship.

Never commit a PFX, private key, password or other signing secret.

## Windows builder

Release-candidate `workflow_dispatch` runs on non-main refs may use:

```text
windows-2025
```

Before source bootstrap they must run `scripts/provision-github-hosted-source-builder.ps1` and then pass the unchanged `scripts/verify-source-builder-host.ps1` production preflight. This binds the candidate to the pinned Visual Studio/Windows SDK/depot_tools/Python/tooling contract, NTFS workspace and free-space requirements.

Production `main` continues to target:

```text
self-hosted
Windows
X64
ghosium-source-builder
```

The production builder must pass the same preflight and provides the controlled Authenticode private-key boundary. Both candidate and production paths require an interactive Windows desktop session for first-usable-window benchmark evidence. Detailed provisioning is maintained in `docs/SOURCE_BUILDER_SETUP.md`.

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

`configure-engine-build.ps1` applies and verifies native NTP, privacy-default, performance and legal transforms before `gn gen`; do not bypass it with ad-hoc source edits.

The pinned build graph currently requires the technical targets:

```powershell
autoninja -C out/Ghosium chrome mini_installer
```

Those target names are internal build API. After compilation, run the same compiled-output verification, source-built benchmark, staging, Setup packaging and maintenance smoke sequence used by the production workflow.

## Release evidence

The controlled build produces evidence including:

```text
GHOSIUM-BUILDER-READY.json
GHOSIUM-SOURCE-BUILD.json
GHOSIUM-PERFORMANCE.json
GHOSIUM-UPSTREAM-MINI-INSTALLER-SMOKE.json
GHOSIUM-SOURCE-STAGE.json
GHOSIUM-PUBLIC-SETUP.json
Ghosium-Browser-Portable.exe
GHOSIUM-CANONICAL-SETUP-SMOKE.json
GHOSIUM-UPDATE-MANIFEST.json
GHOSIUM-VERSION.txt
GHOSIUM-LICENSE.txt
THIRD_PARTY_NOTICES.md
SHA256SUMS.txt
```

The raw source-runtime archive may be retained as an internal workflow artifact for diagnosis/provenance, but it is not the stable end-user release.

## Benchmarking

Use `scripts/benchmark-ghosium-windows.ps1` for comparable Windows measurements. Direct source-built binaries use `-ProfileMode UserDataDir`; historical packaged baselines can use the portable-profile mode where required by that retained binary's profile boundary.

The benchmark records startup, first usable window, memory, process count, handles, CPU, process I/O and idle behavior. It also attempts Windows per-process GPU-memory counters and records Ghosium-owned TCP/UDP endpoint activity. If GPU counters cannot be mapped reliably, the result is explicitly unavailable. Precise byte-level network attribution is not claimed by the endpoint telemetry.

## Legal and security requirements

Brendigo-authored proprietary portions are governed by the Brendigo Proprietary Commercial Software License Agreement in `LICENSE` unless a separate written license states otherwise.

Required third-party licenses, copyright notices and attribution must remain intact in their legal context. They are not Ghosium product branding and must not be rewritten as Brendigo ownership.

Security boundaries take priority over synthetic performance numbers.
