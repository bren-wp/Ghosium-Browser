# Changelog

## 0.1.0 — new Ghosium product line

### Release architecture
- Reset the Ghosium product version line to `0.1.0` while preserving historical `v0.x.y` tags and releases.
- New releases use the independent `ghosium-v0.x.y` tag namespace.
- Removed the snapshot-based stable release workflow that assembled a public browser from a precompiled upstream `chrome-win.zip` archive.
- Made the pinned full-source Windows compile, runtime verification, source-built installer round trip, provenance and SHA-256 manifest the only production release path.
- Existing release tags are treated as immutable; the workflow fails instead of replacing assets under an existing tag.
- Every PR targeting `main` must advance the Ghosium product version and keep bundled component versions synchronized.

### Performance baseline
- Added a Windows benchmark harness for cold and warm startup, first usable window, RAM, process count, handles, CPU, disk transfer counters and active TCP connections.
- Added one-, five- and ten-tab scenarios plus a one-minute idle memory sample.
- Added a hosted Windows CI baseline against the historical `v0.8.0` Setup artifact with an exact SHA-256 check before execution.
- Fixed benchmark profile isolation to use the launcher's validated `--ghosium-portable-profile` control instead of a blocked direct `--user-data-dir` override.
- GPU-memory and per-process network-byte attribution remain explicitly unclaimed until reliable measurements are implemented.

### Product contract
- `VERSION`, Ghosium Privacy, Ghosium Search and built-in Ghosium Store metadata now report `0.1.0`.
- Added a separate Ghosium product-version source contract so public About/version surfaces report the Ghosium version rather than presenting the pinned browser-engine compatibility version as the product version.
- Added a coordinated Windows source migration for the public primary executable `Ghosium-Browser.exe`, proxy helper `Ghosium-Proxy.exe`, installer/update filename constants and Windows VisualElements identity.
- Full-source binary and installer verification now reject a release that still exposes public `chrome.exe` as the installed primary browser executable.
- Release documentation now distinguishes source audit, source patching, full-source compile, runtime verification and release publication.
- Technical upstream GN/Ninja targets and internal DLL/archive names remain implementation dependencies until a separate coordinated rename is proven by successful compile/runtime testing.

### Licensing and attribution
- Ghosium Browser's Brendigo-authored proprietary portions are governed by the Brendigo Proprietary Commercial Software License Agreement Version 1.0 in `LICENSE`.
- Chromium and all other third-party/open-source components remain governed by their respective licenses; Ghosium's proprietary license does not remove or narrow rights granted by those licenses.
- Production release payloads must include verified `GHOSIUM-LICENSE.txt` and `THIRD_PARTY_NOTICES.md` files, and both are covered by the release SHA-256 manifest.
- Brand-surface CI treats required upstream names in the isolated legal-attribution section as legal notices rather than Ghosium product branding, while continuing to reject legacy branding in public product/UI surfaces.

> `0.1.0` is not considered a released source-built browser until the full-source workflow completes successfully on the production commit and creates `ghosium-v0.1.0`.

## Historical development line

The entries below belong to the earlier `v0.x.y` release namespace. They are retained for provenance and are not rewritten or deleted.

## 0.8.0

### Windows release hardening
- Hardened the NSIS bootstrap so release builds verify the exact installer toolchain instead of depending on a mutable package feed.
- Kept real Windows install and same-Setup uninstall smoke testing as a mandatory release gate.
- Added stronger verification around generated Setup and Portable executables and release artifact publication.

### Full-source readiness
- Added pinned Chromium source and Chromium-matched `depot_tools` provenance contracts.
- Added fail-closed Windows x64 self-hosted builder readiness checks, persistent workspace validation and dependency reset hardening.
- Added source branding, Windows identity, Ghosium Search, locale and product-link verification against the pinned Chromium source tree.
- Added source-built runtime and installer round-trip verification tooling, SHA-256 provenance reports and post-merge engine audits on `main`.
- The dedicated `Ghosium Full-Source Windows Build` remained a separate manual self-hosted gate; this historical release did not claim that the full source compile completed.

### CI and supply chain
- Security-sensitive actions used by the self-hosted full-source workflow were pinned to immutable commit SHAs.
- Post-merge `main` changes affecting engine/source branding were re-audited on the exact production branch SHA.
- Historical release/package publication was guarded against duplicate stable tags.

## 0.7.0

### Branding
- Ghosium-only New Tab copy and navigation.
- Ghosium-controlled product links point only to Ghosium-owned domains.
- Engine entry executable was packaged as `Ghosium-Engine.exe`.
- User-facing documentation used Ghosium terminology; legally required third-party attribution remained isolated in notices/license material.

### Search and Store
- Ghosium Search remained the default search endpoint.
- Added complete `store-web/` shared-hosting source for `store.ghosium.com`.
- Store uses PHP + JSON, no SQL database, no application JavaScript and no third-party assets.

### Languages
- Setup language chooser expanded to 30 languages.
- English is the default/fallback; Croatian is included.
- Selected installer locale controls browser launch language.
- Portable mode stores its selected language beside the portable profile.

### Privacy and security
- Added background-networking suppression in the native launcher.
- Preserved sandbox, certificate validation and core process isolation.
- Added validated portable profile/language launcher controls.
- Setup includes Brendigo publisher metadata and local license acceptance page.

### Packaging
- Historical GitHub Releases attached `Ghosium-Browser-Setup.exe` and `Ghosium-Browser-Portable.exe`.
- Source code was delivered through GitHub's automatic source archives.
- Search/Store deployable source remained in the release-tag source code instead of separate web ZIP assets.

## 0.6.0

- Migrated the desktop distribution to a direct pinned upstream open-source browser engine with a small native C++ launcher.
- Added Ghosium Search shared-hosting source, declarative privacy rules and automatic Low Memory mode.
- Added stable Windows Setup/Portable build and release verification.
