# Ghosium source-engine integration

This directory contains Ghosium-owned source transforms, brand assets, localization, Windows identity and deterministic build configuration for the exact upstream engine revision in `ENGINE_SOURCE_REVISION`.

## Product source contract

Ghosium owns the user-facing product layer: Ghosium Browser/Brendigo identity, Ghosium artwork, `Ghosium-Browser.exe`, `Ghosium-Proxy.exe`, `ghost://` / `ghost-untrusted://`, local profile surfaces, native New Tab branding, Ghosium links, native update integration and 38 supported locales.

External services and upstream implementation identifiers are not falsely renamed. Technical source/build symbols may remain where the build graph requires them; required third-party attribution remains in legal material. These internal identifiers must not become public product branding.

## New Tab and privacy


## Security invariants

Browser/renderer/GPU sandboxing, site/process isolation, Safe Browsing, TLS/certificate validation, extension trust and update verification are mandatory. No performance or branding change may weaken these boundaries.

## Build configuration

Windows x64 keeps `is_debug = false`, `is_component_build = false`, `is_chrome_branded = false`, `target_cpu = "x64"`, `enable_background_mode = false` and `use_remoteexec = false`. Production builds do not inject proprietary third-party API credentials.

