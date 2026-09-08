# Ghosium Browser

**Ghosium Browser by Brendigo** is a Windows x64 browser developed as a full-source Ghosium product. The current development version is **0.1.4**.

## Product contract

Ghosium-controlled product surfaces use Ghosium/Brendigo identity:

- product: **Ghosium Browser**
- publisher: **Brendigo**
- home: `https://ghosium.com/`
- search: `https://search.ghosium.com/`
- store: `https://store.ghosium.com/`
- updates: `https://updates.ghosium.com/`
- support: `https://ghosium.com/support`
- security: `https://ghosium.com/security`
- terms: `https://ghosium.com/legal/terms`
- privacy: `https://ghosium.com/legal/privacy-policy`
- licenses: `https://ghosium.com/legal/licenses`

Third-party browser names are forbidden as Ghosium product branding on Ghosium-owned UI, Setup, web services, shortcuts, help surfaces and public distributable executable identity. Required third-party attribution is isolated to legal/license material.

## Versioning and releases

The active release namespace is independent and immutable:

```text
ghosium-v0.1.0
ghosium-v0.1.1
ghosium-v0.1.2
ghosium-v0.1.3
ghosium-v0.1.4
ghosium-v0.2.0
```

Existing releases are never overwritten. A production release is allowed only after the exact commit passes the controlled full-source Windows compile, runtime checks, measured performance evidence, canonical Setup round trip, signing requirements, provenance and SHA-256 manifest generation.

A source transformation audit or hosted CI contract is not proof that a production binary exists. **0.1.4 must not be described as a released source-built binary until the controlled Windows compile succeeds for the exact production commit.**

## Ghosium internal URLs

The Ghosium internal namespace is:

- `ghost://newtab/`
- `ghost://history/`
- `ghost://bookmarks/`
- `ghost://downloads/`
- `ghost://settings/`
- `ghost://profiles/`
- `ghost://extensions/`
- `ghost://passwords/`
- restricted WebUI scheme: `ghost-untrusted://`

`ghost://profiles/` is the canonical Ghosium host for the native profile-picker WebUI controller. `ghost://passwords/` is the canonical Ghosium host for the native password-manager WebUI controller. They no longer depend on `browser_about_handler.cc` redirect aliases. Source verification requires the native controller registrations and rejects restoration of the old alias routing.

Runtime support is considered production-verified only after the full-source compile and runtime tests succeed for the exact release candidate.

## Languages

Ghosium 0.1.4 defines **38 supported product locales**. English (`en-US`) is the primary/default language and Croatian (`hr`) is required and selectable.

```text
en-US, hr, de, fr, es, it, pt-PT, pt-BR, nl, pl,
cs, sk, sl, hu, ro, bg, el, tr, ru, uk,
sv, da, nb, fi, ja, ko, zh-CN, zh-TW, ar, he,
sr, ca, et, lv, lt, id, th, vi
```

Interactive Windows Setup exposes the same locale contract. A fresh install initializes the browser language from the Setup selection; reinstall/update preserves an existing browser preference.

## Windows install, update and uninstall

Public Windows identities are:

```text
Ghosium-Browser.exe
Ghosium-Proxy.exe
Ghosium-Browser-Setup.exe
```

`Ghosium-Browser-Setup.exe` is the canonical maintenance package for normal install, `/S /UPDATE` and `/S /UNINSTALL`. Ghosium does not intentionally distribute a separate public updater or uninstaller executable.

The production update path validates the Ghosium update manifest, newer version, exact byte size, SHA-256, Authenticode publisher and signed Ghosium/Brendigo PE metadata before executing the same Setup package in update mode. The checked-in update manifest is disabled until it describes a real signed package.

## Ghosium Search

The first-party endpoint is:

```text
https://search.ghosium.com/?q={searchTerms}
```

The 0.1.3 public Search interface was rebuilt from the ground up to match Ghosium Browser's dark surface and mint/teal/cyan visual language. The home page presents one focused search box and does not expose index/provider implementation details or developer-oriented operator examples.

`search-web/` uses reusable server-rendered PHP UI components and modern responsive CSS. It has **no JavaScript runtime bundle or client-framework hydration layer** in the search request path. Advanced query parsing remains available in the backend/API without cluttering the public interface.

See `search-web/README.md` for deployment and engine details.

## Ghosium Store

The first-party Store is:

```text
https://store.ghosium.com/
```

`store-web/` contains the shared-hosting implementation. Product Store links are restricted to Ghosium-owned destinations and extension trust remains fail-closed.

## Source build

The production source-build path uses:

- `ENGINE_SOURCE_REVISION` — exact engine source revision;
- `DEPOT_TOOLS_REVISION` — exact build-tool revision;
- `engine/build/windows-x64.args.gn` — reviewed Windows x64 build configuration;
- `scripts/bootstrap-engine-source.ps1` — deterministic source checkout/reset;
- `scripts/apply-engine-branding.ps1` — complete Ghosium source transformation, including product-version and native internal-host rewrites;
- `scripts/configure-engine-build.ps1` — reviewed build configuration;
- source/fork, executable, updater, locale and performance verifiers;
- `scripts/verify-engine-build-output.ps1` — compiled output/runtime verification;
- `scripts/benchmark-ghosium-windows.ps1` — comparable Windows performance evidence;
- `scripts/assemble-source-release-stage.ps1` — verified runtime staging;
- `scripts/build-source-release-installer.ps1` — canonical Setup packaging/signing;
- `scripts/smoke-test-windows-installer.ps1` — install/update/uninstall round trip;
- `scripts/generate-update-manifest.ps1` — exact signed Setup update metadata.

The default controlled builder workspace is `C:\src\ghosium-engine`. Technical source-tree identifiers required by the engine build API may remain inside engineering tooling until a coordinated compile/runtime migration proves a replacement. They are not accepted as Ghosium public product branding.

## Performance and stability

Performance work is measurement-driven. The benchmark records:

- cold and warm startup to first usable window;
- 1, 5 and 10 tab scenarios;
- working set, private and paged memory;
- process count and handles;
- CPU activity and process I/O deltas;
- a 60-second one-tab idle interval;
- best-effort per-process Windows GPU memory;
- best-effort Ghosium-owned TCP/UDP endpoint activity.

When Windows/driver GPU process counters are unavailable, the result explicitly records `available=false`; it does not fabricate a zero. TCP/UDP endpoint activity is not represented as byte-level network attribution.

Current conservative source-level defaults use native engine mechanisms: Memory Saver is enabled by default for profiles without an explicit user selection, medium aggressiveness/tab freezing are preserved, and legacy background-app keep-alive is disabled on Windows.

No performance optimization may disable or weaken sandboxing, renderer/site isolation, certificate validation, extension verification or update verification. Renderer-process caps are not used as a RAM shortcut.

Every source-built release candidate must produce `GHOSIUM-PERFORMANCE.json` from the newly compiled `Ghosium-Browser.exe`. No numerical 0.1.4 performance claim is valid until that evidence exists.

## Production signing

Production `main` builds require the controlled Windows builder to have the configured Brendigo/Ghosium Authenticode signing identity and RFC3161 timestamp endpoint. Browser, proxy and Setup publisher relationships must validate before production update metadata or release publication can proceed.

Signing private keys and certificate secrets must never be committed to the repository.

## Release evidence

A successful production build creates evidence including:

- `GHOSIUM-BUILDER-READY.json`
- `GHOSIUM-SOURCE-BUILD.json`
- `GHOSIUM-PERFORMANCE.json`
- `GHOSIUM-UPSTREAM-MINI-INSTALLER-SMOKE.json`
- `GHOSIUM-SOURCE-STAGE.json`
- `GHOSIUM-PUBLIC-SETUP.json`
- `GHOSIUM-CANONICAL-SETUP-SMOKE.json`
- `GHOSIUM-UPDATE-MANIFEST.json`
- `GHOSIUM-VERSION.txt`
- `GHOSIUM-LICENSE.txt`
- `THIRD_PARTY_NOTICES.md`
- `SHA256SUMS.txt`

Internal build intermediates are evidence only; the end-user Windows product is the canonical Ghosium Setup package.

## Repository layout

```text
.github/workflows/      CI, source-build, update, release and regression contracts
engine/                 Ghosium product metadata, localization, branding and build configuration
extension/              Ghosium Privacy and New Tab component
search-provider/        Ghosium Search browser integration
installer/              canonical same-Setup Windows installer/update/uninstall definition
scripts/                source transformation, verification, packaging and benchmark tooling
search-web/             shared-hosting Ghosium Search
updates-web/            fail-closed Ghosium update endpoint
store-web/              shared-hosting Ghosium Store
docs/                   architecture, security, release, performance and build documentation
benchmarks/              reproducible benchmark evidence
```

Retired wrapper-launcher and legacy Portable packaging are intentionally not part of the current source-built architecture.

## License and third-party rights

Ghosium Browser is distributed under the **Brendigo Proprietary Commercial Software License Agreement** in `LICENSE`. Brendigo-authored code, branding, artwork, documentation, patches and other proprietary portions are licensed under that agreement unless a separate written license explicitly states otherwise. Public repository visibility does not by itself grant an open-source license to Brendigo-authored proprietary material.

Chromium and every other third-party or open-source component remain governed by their own licenses. Nothing in the Ghosium proprietary license removes, narrows, replaces or overrides rights granted directly under those third-party licenses. Required notices and attribution are preserved in `THIRD_PARTY_NOTICES.md` and applicable bundled license material.
