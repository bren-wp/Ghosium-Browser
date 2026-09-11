# Ghosium source-engine integration

The active product baseline is **0.0.3**.

This directory contains Ghosium-owned source transforms, brand assets, localization, Windows identity and deterministic build configuration for the exact Chromium source revision in `ENGINE_SOURCE_REVISION`.

## Product source contract

Ghosium owns the Windows product layer: Ghosium Browser/Brendigo identity, artwork, `Ghosium-Browser.exe`, `Ghosium-Proxy.exe`, `ghost://` / `ghost-untrusted://`, local profile surfaces, native New Tab branding, first-party product links, native update integration and supported locales.

Technical Chromium/GN symbols may remain where required by the build graph. Required third-party attribution is legal material and is not relabeled as Ghosium.

## 0.0.3 privacy and performance

Windows source transforms preserve stronger defaults for third-party cookies, search suggestions, speculative network prediction/preloading, remote alternate-error pages and online spelling upload. Remote provider-owned New Tab promotion/Doodle paths covered by the source contract remain disabled.

Native Memory Saver and `enable_background_mode = false` remain part of the performance configuration. Security mechanisms are not disabled for benchmark results.

## Security invariants

Browser/renderer/GPU sandboxing, site/process isolation, Safe Browsing, TLS/certificate validation, extension trust and update verification are mandatory.

Native Windows update downloads use unique secure temporary session directories and enforce exact first-party endpoints, redirect rejection, byte-size/SHA-256 validation, Authenticode publisher validation and signed PE metadata checks before Setup launch.

## Build configuration

Windows x64 keeps deterministic release build settings including `is_debug = false`, `is_component_build = false`, `is_chrome_branded = false`, `target_cpu = "x64"`, `enable_background_mode = false` and `use_remoteexec = false`. Production builds do not inject proprietary Google API credentials.

The canonical flow is documented in `../BUILDING.md`. Android is a separate client module under `../android/` and does not alter the pinned Windows source-engine revision.
