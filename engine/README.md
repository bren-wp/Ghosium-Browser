# Ghosium source-engine integration

The active product baseline is `0.0.2`.

The current development target is **Ghosium Browser 0.0.2** (`ghosium-v0.0.2`). Earlier releases and candidates remain historical evidence only and are not canonical 0.0.2 full-source production evidence.

This directory contains Ghosium-owned source transforms, brand assets, localization, Windows identity and deterministic build configuration for the exact Chromium source revision in `ENGINE_SOURCE_REVISION`.

## Product source contract

Ghosium owns the user-facing product layer: Ghosium Browser/Brendigo identity, Ghosium artwork, `Ghosium-Browser.exe`, `Ghosium-Proxy.exe`, `ghost://` / `ghost-untrusted://`, local profile surfaces, native New Tab branding, Ghosium links, native update integration and 38 supported locales.

External services and upstream implementation identifiers are not falsely renamed. Chromium/GN technical symbols may remain where the build graph requires them; required third-party attribution remains in legal material.

## New Tab and privacy

0.0.2 applies the Ghosium mark to the native New Tab source, removes remote Doodle initialization and disables provider-owned NTP cloud/promo surfaces. Privacy defaults block third-party cookies and disable search suggestions, speculative network prediction/preloading, remote alternate-error pages and online spelling upload for new/default profiles.

## Security invariants

Browser/renderer/GPU sandboxing, site/process isolation, Safe Browsing, TLS/certificate validation, extension trust and update verification are mandatory. No performance change may weaken these boundaries.

Native Windows update downloads use a unique per-session directory under the secure Windows temporary directory. Exact first-party endpoint rules, redirect rejection, size/SHA-256 verification, same-publisher Authenticode verification and signed PE product/company/version checks all complete before Setup launch.

## Build configuration

Windows x64 keeps `is_debug = false`, `is_component_build = false`, `is_chrome_branded = false`, `target_cpu = "x64"`, `enable_background_mode = false` and `use_remoteexec = false`. Production builds do not inject proprietary Google API credentials.

NSIS is resolved only from trusted machine-wide Program Files locations or from the exact hash-pinned official portable archive downloaded over HTTPS-only redirects. Benchmark tooling refuses pre-existing browser sessions and scopes cleanup to benchmark-owned process trees.

The canonical build flow is documented in `../BUILDING.md`. Canonical 0.0.2 production requires exact-SHA source compile, runtime, benchmark, package, provenance, production-signing evidence and the complete install -> runtime -> same-Setup update -> runtime -> uninstall lifecycle before canonical publication.
