# Ghosium Browser

**Ghosium Browser by Brendigo** is a Windows x64 web browser developed as a full-source Ghosium product. The current development version is **0.1.2**.

## Product contract

Ghosium-controlled product surfaces use only Ghosium/Brendigo identity:

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

Legacy upstream browser product names are forbidden from Ghosium-owned UI, Setup, web services, shortcuts, help surfaces and public distributable executable identity. Required third-party attribution is isolated to legal/license material.

## Versioning and releases

The active release namespace is independent and immutable:

```text
ghosium-v0.1.0
ghosium-v0.1.1
ghosium-v0.1.2
ghosium-v0.2.0
```

Existing releases are never overwritten. A production release is allowed only after the exact commit passes the controlled full-source Windows build, runtime checks, canonical Setup round trip, signing requirements, provenance generation and SHA-256 manifest generation.

A source transformation audit or hosted CI contract is not proof that a production binary exists. **0.1.2 must not be described as source-built until the controlled Windows compile succeeds.**

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

Runtime support is considered verified only by the full-source compile and runtime tests.

## Languages

Ghosium 0.1.2 defines **38 supported product locales**. English (`en-US`) is the primary/default language and Croatian (`hr`) is required and selectable.

The current locale set is:

```text
en-US, hr, de, fr, es, it, pt-PT, pt-BR, nl, pl,
cs, sk, sl, hu, ro, bg, el, tr, ru, uk,
sv, da, nb, fi, ja, ko, zh-CN, zh-TW, ar, he,
sr, ca, et, lv, lt, id, th, vi
```

Interactive Windows Setup exposes the same 38-language contract. English is selected by default. On a fresh installation the selected Setup language initializes the native browser locale. Reinstall/update does not overwrite an existing browser language preference, so a language later changed from Ghosium Settings remains the user's choice.

## Windows install, update and uninstall

The public Windows identities are:

```text
Ghosium-Browser.exe
Ghosium-Proxy.exe
Ghosium-Browser-Setup.exe
```

Ghosium uses one maintenance package. `Ghosium-Browser-Setup.exe` performs:

```text
normal install
/S /UPDATE
/S /UNINSTALL
```

No separately distributed updater or uninstaller executable is part of the product. Windows Installed apps points to the same installed Setup package.

The update sequence is:

```text
About Ghosium Browser
  -> https://updates.ghosium.com/windows/stable.json
  -> validate schema, product, platform, channel and newer version
  -> download the exact Ghosium-Browser-Setup.exe path over HTTPS
  -> reject redirects
  -> validate exact byte size and SHA-256
  -> validate Authenticode and matching publisher
  -> validate signed PE Ghosium/Brendigo product metadata and version
  -> run the same Setup package in update mode
```

The checked-in update manifest is disabled by default. Production update metadata is generated only from the exact verified and signed Setup artifact.

## Ghosium Search

The first-party search endpoint is:

```text
https://search.ghosium.com/?q={searchTerms}
```

`search-web/` is the shared-hosting implementation. It supports a bounded local index, search operators, domain diversity, statistics, a hardened crawler and explicit shortcuts. It is not represented as a complete independent index of the public web.

## Ghosium Store

The first-party Store is:

```text
https://store.ghosium.com/
```

`store-web/` contains the shared-hosting implementation. Product Store links are restricted to the Ghosium domain and extension trust remains fail-closed.

## Source build

The production source-build path uses:

- `ENGINE_SOURCE_REVISION` — exact engine source revision;
- `DEPOT_TOOLS_REVISION` — exact build-tool revision;
- `engine/build/windows-x64.args.gn` — reviewed Windows x64 build configuration;
- `scripts/bootstrap-engine-source.ps1` — deterministic source checkout/reset;
- `scripts/apply-engine-branding.ps1` — Ghosium source transformation;
- `scripts/configure-engine-build.ps1` — verified build configuration and performance defaults;
- `scripts/verify-engine-fork.ps1` — transformed-source verification;
- `scripts/verify-engine-windows-executable.ps1` — public Windows executable verification;
- `scripts/verify-engine-version-updater.ps1` — native updater verification;
- `scripts/verify-engine-performance-defaults.ps1` — native performance-default verification;
- `scripts/verify-engine-build-output.ps1` — compiled output and runtime verification;
- `scripts/assemble-source-release-stage.ps1` — verified runtime staging;
- `scripts/build-source-release-installer.ps1` — canonical Setup packaging/signing;
- `scripts/smoke-test-windows-installer.ps1` — install/update/uninstall round trip;
- `scripts/generate-update-manifest.ps1` — exact signed Setup update metadata.

Technical source-tree identifiers required by the engine build API may remain inside engineering tooling until a coordinated compile/runtime migration proves a replacement. They are not accepted as Ghosium product branding or public installed executable identity.

## Performance and stability

Performance work is measurement-driven. The immutable historical Windows baseline is retained under `benchmarks/windows/`, and `scripts/benchmark-ghosium-windows.ps1` records cold/warm launch, first usable window, process count, memory, CPU, handles, I/O and idle behavior.

0.1.2 introduces two conservative source-level defaults that use existing engine mechanisms:

- native **Memory Saver is enabled by default** for profiles that have not explicitly chosen a state;
- legacy background-app keep-alive is disabled in the Windows build so closing the last browser window does not intentionally keep that mode resident.

Medium Memory Saver aggressiveness, native tab-freezing behavior and the existing discard threshold remain unchanged. Explicit user preferences continue to take precedence.

No performance optimization may disable or weaken sandboxing, renderer/site isolation, certificate validation, extension verification or update verification. Renderer-process caps are not used as a RAM shortcut.

No claim that 0.1.2 is faster or uses less memory than the historical baseline is valid until the source-built 0.1.2 binary is benchmarked with the same methodology.

## Production signing

Production `main` builds require the controlled Windows builder to have the configured Brendigo/Ghosium Authenticode signing identity and RFC3161 timestamp endpoint. The browser, proxy and Setup publisher relationship must validate before production update metadata or release publication can proceed.

Signing private keys and certificate secrets must never be committed to this repository.

## Release evidence

A controlled successful production build creates evidence including:

- `GHOSIUM-BUILDER-READY.json`
- `GHOSIUM-SOURCE-BUILD.json`
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
updates-web/            shared-hosting Ghosium update endpoint
store-web/              shared-hosting Ghosium Store
docs/                   architecture, security, release, performance and build documentation
benchmarks/              reproducible benchmark evidence
```

Retired wrapper-launcher, legacy Portable packaging and internal chat-handoff files are intentionally not part of the 0.1.2 source-built architecture.

## License and third-party rights

Ghosium Browser is distributed under the **Brendigo Proprietary Commercial Software License Agreement** in `LICENSE`. Brendigo-authored code, branding, artwork, documentation, patches and other proprietary portions are licensed under that agreement unless a separate written license explicitly states otherwise. Public repository visibility does not by itself grant an open-source license to Brendigo-authored proprietary material.

Chromium and every other third-party or open-source component remain governed by their own licenses. Nothing in the Ghosium proprietary license removes, narrows, replaces or overrides rights granted directly under those third-party licenses. Required notices and attribution are preserved in `THIRD_PARTY_NOTICES.md` and the applicable bundled license material.
