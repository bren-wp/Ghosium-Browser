# Ghosium Browser

**Ghosium Browser by Brendigo** is a source-derived Windows x64 browser fork. The current product line starts at **0.1.0** and is developed as a full-source Ghosium product rather than a precompiled upstream snapshot with a renamed launcher or installer.

## Current release contract

The Ghosium product line uses semantic versions and its own immutable tag namespace:

```text
ghosium-v0.1.0
ghosium-v0.1.1
ghosium-v0.2.0
```

Historical `v0.x.y` tags and releases remain untouched.

A production Ghosium release is publishable only after the pinned full-source Windows workflow succeeds for the exact release commit. The release gate requires:

1. exact pinned source/toolchain checkout;
2. complete Ghosium source transformation and source verification;
3. full browser compile;
4. build-tree runtime smoke verification without disabling the sandbox;
5. technical source-installer verification;
6. verified extraction of the newly built source-runtime archive;
7. canonical Ghosium release-stage assembly;
8. public `Ghosium-Browser-Setup.exe` creation from the Ghosium NSIS installer rather than renaming an upstream installer;
9. production Authenticode signing of browser, proxy and Setup with a consistent publisher identity;
10. canonical install → runtime → `/UPDATE` → runtime → `/UNINSTALL` round-trip verification with profile/language preservation;
11. production update manifest generation bound to the exact signed Setup SHA-256 and byte size;
12. provenance reports and `SHA256SUMS.txt`;
13. immutable `ghosium-v0.x.y` release creation.

A configured workflow, source audit, source patch, snapshot package, launcher package or technical mini-installer result is **not** proof of a production Ghosium release. Production status requires an actual successful controlled Windows full-source run and its evidence.

## Product identity

Ghosium-controlled product surfaces use:

- product: **Ghosium Browser**
- publisher/company: **Brendigo**
- home: `https://ghosium.com/`
- search: `https://search.ghosium.com/`
- store: `https://store.ghosium.com/`
- update service: `https://updates.ghosium.com/`
- support: `https://ghosium.com/support`
- security: `https://ghosium.com/security`
- terms: `https://ghosium.com/legal/terms`
- privacy: `https://ghosium.com/legal/privacy-policy`
- licenses: `https://ghosium.com/legal/licenses`

Required third-party licenses, copyright notices and attribution are preserved. They belong in legal/license surfaces and are not treated as Ghosium product branding.

## Internal Ghosium URLs

The source fork owns the Ghosium internal namespace:

- `ghost://newtab/`
- `ghost://history/`
- `ghost://bookmarks/`
- `ghost://downloads/`
- `ghost://settings/`
- `ghost://profiles/`
- `ghost://extensions/`
- `ghost://passwords/`
- restricted WebUI scheme: `ghost-untrusted://`

The repository contains source rewrite and verification tooling for this contract. Runtime support is considered verified only when the pinned full-source compile and runtime tests pass.

## Ghosium Search

The browser distribution fallback search endpoint is:

```text
https://search.ghosium.com/?q={searchTerms}
```

The bundled search-provider manifest, Store metadata and browser `VERSION` are required by CI to remain synchronized. The shared-hosting search service is a first-party Ghosium implementation; its local JSON index is intentionally bounded and is not represented as a complete independent index of the public web.

## Ghosium Store

The Ghosium Store destination is:

```text
https://store.ghosium.com/
```

Ghosium-owned extension UI and product links must not send users to an upstream browser store. Extension package trust and signature/security behavior must remain fail-closed.

## Native Windows update architecture

The Windows About page uses Ghosium's native updater integrated into the pinned browser source. It uses browser networking rather than a shell helper or a separate updater executable.

The stable update sequence is:

```text
About Ghosium Browser
  -> https://updates.ghosium.com/windows/stable.json
  -> validate schema/product/platform/channel/version
  -> download Ghosium-Browser-Setup.exe from the trusted update host
  -> validate exact size + SHA-256
  -> validate Authenticode/publisher trust
  -> launch /S /UPDATE /DELETESELF
```

The same `Ghosium-Browser-Setup.exe` is installed as the maintenance package and handles `/UNINSTALL`. Ghosium does not intentionally ship `update.exe`, `updater.exe` or a standalone `uninstall.exe`.

The checked-in update manifest is disabled by default. An enabled production manifest is generated only from a verified canonical Setup, and the production `main` path requires Authenticode validation before release evidence is accepted.

## Windows identity

The source transformation rewrites Windows install/product identity to Ghosium/Brendigo values for product path, base application identity, browser ProgID prefix, HTML/PDF document identity, direct-launch scheme, primary executable and proxy executable. Technical upstream identifiers that remain internal compatibility/security contracts are not renamed blindly.

The canonical profile path is:

```text
%LOCALAPPDATA%\Brendigo\Ghosium\User Data
```

The public Windows executable/package identities are:

```text
Ghosium-Browser.exe
Ghosium-Proxy.exe
Ghosium-Browser-Setup.exe
```

A verified release fails if the installed public browser remains `chrome.exe` or if the public Setup is only a renamed technical `mini_installer.exe`.

## Source build

The full-source Windows path uses:

- `ENGINE_SOURCE_REVISION` — pinned browser-engine source;
- `DEPOT_TOOLS_REVISION` — pinned build tooling matched against the same source DEPS;
- `engine/build/windows-x64.args.gn` — reviewed Windows x64 configuration;
- `scripts/bootstrap-engine-source.ps1` — controlled source checkout/reset;
- `scripts/apply-engine-branding.ps1` — complete Ghosium source transformation;
- `scripts/verify-engine-fork.ps1` — transformed-source verification;
- `scripts/verify-engine-windows-executable.ps1` — Windows executable/source-shell verification;
- `scripts/verify-engine-version-updater.ps1` — native updater verification;
- `scripts/verify-engine-build-output.ps1` — compiled output/runtime verification;
- `scripts/smoke-test-source-windows-installer.ps1` — technical source-installer verification;
- `scripts/assemble-source-release-stage.ps1` — verified source-runtime extraction/staging;
- `scripts/build-source-release-installer.ps1` — canonical Setup packaging and production signing;
- `scripts/smoke-test-windows-installer.ps1` — public install/update/uninstall runtime round trip;
- `scripts/generate-update-manifest.ps1` — exact Setup update metadata.

Upstream GN/Ninja target or intermediate artifact names may remain where a coordinated rename has not yet been proven by compile/runtime tests. Such names are internal build-system dependencies, not accepted public product identity.

## Production signing

On production `main`, the controlled source builder requires:

- `GHOSIUM_SIGN_CERT_THUMBPRINT` from GitHub Actions secrets;
- `GHOSIUM_TIMESTAMP_URL` from GitHub Actions variables;
- the selected certificate and accessible private key in the runner account's Windows certificate store;
- the pinned Windows SDK `signtool.exe`.

The signing pipeline uses SHA-256 and RFC3161 timestamping and requires the signed browser, proxy and Setup publisher relationship to verify before the production update manifest/release can proceed. Signing private keys and PFX passwords must never be committed to the repository.

## Release evidence

A successful controlled build produces evidence including:

- `GHOSIUM-BUILDER-READY.json`
- `GHOSIUM-SOURCE-BUILD.json`
- `GHOSIUM-UPSTREAM-MINI-INSTALLER-SMOKE.json`
- `GHOSIUM-SOURCE-STAGE.json`
- `GHOSIUM-PUBLIC-SETUP.json`
- `GHOSIUM-CANONICAL-SETUP-SMOKE.json`
- `GHOSIUM-UPDATE-MANIFEST.json` on production `main`
- `GHOSIUM-VERSION.txt`
- `GHOSIUM-LICENSE.txt`
- `THIRD_PARTY_NOTICES.md`
- `SHA256SUMS.txt`

The raw technical source-runtime archive can be retained as internal workflow evidence but is not the stable end-user product release asset.

## Performance work

Performance changes are measurement-driven. The repository includes `scripts/benchmark-ghosium-windows.ps1`, which records cold/warm startup, first usable window, memory, process/handle counts, normalized CPU, disk transfer counters and active TCP connection count across controlled scenarios.

`.github/workflows/performance-baseline.yml` benchmarks the immutable historical `v0.8.0` Windows Setup after SHA-256 verification. No new performance claim should be made until a comparable source-built 0.1.x result exists.

The benchmark does not claim measurements that the implementation cannot gather reliably, such as a truly cache-flushed cold boot or precise per-process network/GPU attribution where unavailable.

## Security invariants

Ghosium performance, privacy, branding or packaging work must not globally disable:

- the browser sandbox or renderer sandbox;
- site isolation;
- certificate validation or TLS error handling;
- extension trust verification;
- update hash/signature/publisher verification.

The launcher rejects high-risk command-line overrides that would remove these protection boundaries.

## Repository layout

```text
.github/workflows/      CI, source-build, release and regression contracts
engine/                 Ghosium product metadata, branding assets and GN config
extension/              Ghosium Privacy + New Tab component
search-provider/        Ghosium Search provider component
launcher/               native Ghosium Windows launcher
installer/              canonical NSIS Setup and portable packaging
scripts/                source patching, verification, release and benchmark tooling
search-web/             Ghosium Search web service
updates-web/            first-party browser update endpoint payload
store-web/              Ghosium Store web service
docs/                   architecture, security, release and build documentation
```

## Release immutability

Existing stable releases are never overwritten. If `ghosium-v0.x.y` already exists, the release workflow fails instead of replacing its assets. Every production release therefore requires an unused synchronized product version.

## License and third-party rights

Ghosium Browser is distributed under the **Brendigo Proprietary Commercial Software License Agreement** in `LICENSE`. Brendigo-authored code, branding, artwork, documentation, patches and other proprietary portions are licensed under that agreement unless a separate written license explicitly states otherwise. Public repository visibility does not by itself grant an open-source license to Brendigo-authored proprietary material.

Chromium and every other third-party or open-source component remain governed by their own licenses. Nothing in the Ghosium proprietary license removes, narrows, replaces or overrides rights granted directly under those third-party licenses. Required notices and attribution are preserved in `THIRD_PARTY_NOTICES.md` and the applicable bundled license material.
