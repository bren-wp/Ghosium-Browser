<p align="center">
  <img src="engine/branding/ghosium-mark.svg" width="112" alt="Ghosium Browser icon">
</p>

# Ghosium Browser 0.0.2

**Ghosium Browser by Brendigo** is a Windows x64 browser. The active product version is **0.0.2**.

The current branch is the canonical full-source production candidate. Publication is allowed only after the exact source-build, branding, privacy, performance, installer, signing, provenance and updater contracts pass. A previously published GitHub Preview remains separate from canonical production evidence and is not used to satisfy these gates.

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

The native upstream engine source transformation applies Ghosium product identity to browser-owned surfaces, including New Tab, tabs, History, Bookmarks, Downloads, About, Settings, profiles, password manager, extensions, print/PDF surfaces, application menu, Windows executable metadata, installer and internal WebUI routing.

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

0.0.2 uses stronger native defaults for new/default profiles: third-party cookies blocked, search suggestions disabled, speculative network prediction/preloading disabled, remote alternate-error pages disabled and online spelling-service upload required to remain disabled by default.

Security boundaries remain mandatory: Safe Browsing, TLS/certificate validation, browser/renderer/GPU sandboxing, site/process isolation, extension verification and update hash/signature/publisher validation must not be weakened for performance.

## Performance

Native Memory Saver remains enabled by default for profiles without an explicit selection and legacy background-app keep-alive is disabled. New Tab remote Doodle initialization and unnecessary NTP prefetch/prerender paths are removed or disabled.

Numerical performance claims remain reserved for verified `GHOSIUM-PERFORMANCE.json` evidence from the controlled full-source benchmark workflow.

## Windows packages

Canonical full-source production publication requires:

```text
Ghosium-Browser-Setup.exe
Ghosium-Browser-Portable.exe
```

The Setup lifecycle contract requires install → runtime → same-Setup update → runtime → same-Setup uninstall verification. Canonical publication additionally requires exact source provenance, SHA-256 evidence and the configured production-signing checks.

## Release status

**Ghosium Browser 0.0.2 is a production candidate, not yet a canonical published release.**

The checked-in stable update manifest remains fail-closed (`enabled:false`, empty SHA-256, zero size). Canonical publication requires exact full-source candidate evidence, runtime/performance verification, canonical Setup/Portable provenance, production signing and release-manifest binding.

Ghosium 0.0.2 defines **38 supported product locales**. English (`en-US`) is the default language and Croatian (`hr`) is required.

## License and third-party rights

Ghosium Browser is distributed under the **Brendigo Proprietary Commercial Software License Agreement** in `LICENSE`. Public repository visibility does not by itself grant an open-source license to Brendigo-authored proprietary material.

Chromium and every other third-party or open-source component remain governed by their own licenses. Required notices and attribution are preserved in `THIRD_PARTY_NOTICES.md` and applicable bundled license material.
