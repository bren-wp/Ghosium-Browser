<p align="center">
  <img src="engine/branding/ghosium-mark.svg" width="112" alt="Ghosium Browser icon">
</p>

# Ghosium Browser 0.0.1

**Ghosium Browser by Brendigo** is a Windows x64 browser. The active product version is **0.0.1**.

The current public downloadable build is **Ghosium Browser 0.0.1 Preview 1**, published through the verified GitHub-hosted pinned-snapshot release path. The separate canonical full-source production build remains subject to its stricter source-build, performance, signing, provenance and updater gates.

Current public release: `ghosium-v0.0.1-preview.1`  
Release page: `https://github.com/bren-wp/Ghosium-Browser/releases/tag/ghosium-v0.0.1-preview.1`

This repository uses **0.0.1 as the clean product baseline**. Older product-version numbering is intentionally not part of the active documentation.

## Product identity

- Product: **Ghosium Browser**
- Publisher: **Brendigo**
- Home: `https://ghosium.com/`
- Store: `https://store.ghosium.com/`
- Updates: `https://updates.ghosium.com/`
- Support: `https://ghosium.com/support`
- Security: `https://ghosium.com/security`
- Privacy: `https://ghosium.com/legal/privacy-policy`
- Default external web search provider: Google Search

Ghosium-owned UI uses Ghosium branding. Third-party names are retained only where technically or legally accurate, such as external search-provider identification, standardized WebExtension APIs, internal build dependencies and required license attribution.

## Ghosium interface

The native upstream engine source transformation applies Ghosium product identity to browser-owned surfaces, including New Tab, About, Settings, profiles, password manager, application menu, Windows executable metadata, installer and internal WebUI routing.

The native New Tab uses the Ghosium product mark, neutral Ghosium-owned search copy and direct external search routing. Provider-owned Doodles, OneGoogleBar, cloud modules, AI/Composebox/Threads entry points, Lens/voice New Tab entry points, action chips and browser promotional surfaces are disabled by the Ghosium transform.

## Internal URLs

- `ghost://newtab/`
- `ghost://history/`
- `ghost://bookmarks/`
- `ghost://downloads/`
- `ghost://settings/`
- `ghost://profiles/`
- `ghost://extensions/`
- `ghost://passwords/`
- restricted WebUI scheme: `ghost-untrusted://`

## Privacy and security

0.0.1 uses stronger native defaults for new/default profiles: third-party cookies blocked, search suggestions disabled, speculative network prediction/preloading disabled, remote alternate-error pages disabled and online spelling-service upload required to remain disabled by default.

Security boundaries remain mandatory: Safe Browsing, TLS/certificate validation, browser/renderer/GPU sandboxing, site/process isolation, extension verification and update hash/signature/publisher validation must not be weakened for performance.

## Performance

Native Memory Saver remains enabled by default for profiles without an explicit selection and legacy background-app keep-alive is disabled. New Tab remote Doodle initialization and unnecessary NTP prefetch/prerender paths are removed or disabled.

The public 0.0.1 Preview does not establish canonical full-source performance claims. Numerical performance claims remain reserved for verified `GHOSIUM-PERFORMANCE.json` evidence from the controlled full-source benchmark workflow.

## Windows packages

The **currently published Preview** provides:

```text
Ghosium-Browser-Setup.exe
```

Its release also carries `GHOSIUM-PREVIEW-BUILD.json`, `GHOSIUM-PREVIEW-SETUP-SMOKE.json`, `SHA256SUMS.txt` and `BUILD-STATUS.txt`. The Setup passed install, runtime, same-Setup update, runtime and uninstall verification on GitHub Actions.

The **canonical full-source production** release contract additionally requires:

```text
Ghosium-Browser-Setup.exe
Ghosium-Browser-Portable.exe
```

Canonical Setup/Portable publication remains a separate production gate and is not implied by the Preview release.

## Release status

**Ghosium Browser 0.0.1 Preview 1 is publicly released.** It is a GitHub-hosted pinned Chromium snapshot Preview using the same release model previously used for the superseded 0.1.8 Preview. It is not the canonical full-source production release.

The checked-in stable update manifest remains fail-closed (`enabled:false`, empty SHA-256, zero size) for the Preview. Canonical production publication still requires exact full-source candidate evidence, runtime/performance verification, canonical Setup/Portable provenance, production signing and update-manifest binding.

Ghosium 0.0.1 defines **38 supported product locales**. English (`en-US`) is the default language and Croatian (`hr`) is required.

## License and third-party rights

Ghosium Browser is distributed under the **Brendigo Proprietary Commercial Software License Agreement** in `LICENSE`. Public repository visibility does not by itself grant an open-source license to Brendigo-authored proprietary material.

Chromium and every other third-party or open-source component remain governed by their own licenses. Required notices and attribution are preserved in `THIRD_PARTY_NOTICES.md` and applicable bundled license material.
