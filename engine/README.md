# Ghosium source-engine integration

The active product baseline is `0.0.1`.

The current public downloadable build is **Ghosium Browser 0.0.1 Preview 1** (`ghosium-v0.0.1-preview.1`). It is a verified pinned-snapshot Preview, not the canonical full-source production release.

This directory contains Ghosium-owned source transforms, brand assets, localization, Windows identity and deterministic build configuration for the exact Chromium source revision in `ENGINE_SOURCE_REVISION`.

## Product source contract

Ghosium owns the user-facing product layer: Ghosium Browser/Brendigo identity, Ghosium artwork, `Ghosium-Browser.exe`, `Ghosium-Proxy.exe`, `ghost://` / `ghost-untrusted://`, local profile surfaces, native New Tab branding, Ghosium links, native update integration and 38 supported locales.

External services and upstream implementation identifiers are not falsely renamed. Chromium/GN technical symbols may remain where the build graph requires them; required third-party attribution remains in legal material.

## New Tab and privacy

0.0.1 applies the Ghosium mark to the native New Tab source, removes remote Doodle initialization and disables provider-owned NTP cloud/promo surfaces. Privacy defaults block third-party cookies and disable search suggestions, speculative network prediction/preloading, remote alternate-error pages and online spelling upload for new/default profiles.

## Security invariants

Browser/renderer/GPU sandboxing, site/process isolation, Safe Browsing, TLS/certificate validation, extension trust and update verification are mandatory. No performance change may weaken these boundaries.

## Build configuration

Windows x64 keeps `is_debug = false`, `is_component_build = false`, `is_chrome_branded = false`, `target_cpu = "x64"`, `enable_background_mode = false` and `use_remoteexec = false`. Production builds do not inject proprietary Google API credentials.

The canonical build flow is documented in `../BUILDING.md`. The public 0.0.1 Preview uses a separate pinned-snapshot workflow and its evidence explicitly does not claim a full-source production build. Canonical 0.0.1 production still requires exact-SHA source compile, runtime, benchmark, package, provenance and production-signing evidence before canonical publication.
