# Changelog

## 0.0.3 — Windows + Android release candidate

### Windows

- Unified the installed profile contract at `%LOCALAPPDATA%\Brendigo\Ghosium\User Data`.
- Fixed Portable profile isolation so the hardened launcher, rather than a filtered public `--user-data-dir` override, owns the profile path.
- Reworked Portable packaging around a versioned runtime cache with staging, atomic promotion and a ready marker.
- Avoided re-extracting the full Portable runtime on every launch.
- Added recovery for interrupted/stale Portable preparation and concurrent extraction races.
- Hardened launcher noninteractive behavior so QA/headless failures return an exit code instead of blocking on a modal dialog.
- Added C++20 launcher compilation/self-test and Setup/Portable package execution coverage to the 0.0.3 quality gate.
- Fixed canonical NSIS invocation to use absolute script paths, eliminating the historical duplicated `installer/installer/assets` path workaround.

### Android

- Added the native Ghosium Android application (`com.brendigo.ghosium`) for Android 10+/API 29+.
- Added Ghosium Material UI with address/search input, Back, Forward, Home and Reload controls.
- Added local New Tab, EN/HR resources, downloads, file chooser, fullscreen media, Desktop Site, Find in Page, Share and clear-browsing-data controls.
- Added renderer-process recovery and activity state restoration.
- Blocked third-party cookies and mixed content, disabled WebView file/content access, kept Safe Browsing enabled and made TLS errors fail closed.
- Added explicit confirmation before handing non-HTTP(S) schemes to external applications.
- Fixed host/port URL resolution such as `localhost:8443` and kept URL encoding compatible with API 29.
- Disabled Android cloud backup and device-to-device transfer for browser-local data.
- Added unit tests, lint-as-error enforcement and release/minification verification.

### Release engineering and documentation

- Synchronized Ghosium Privacy Store metadata with product version 0.0.3.
- Added a production orchestrator that requires a stable signed Android APK before dispatching the canonical signed Windows full-source release.
- Added Android release provenance and final three-asset release verification.
- Updated README, architecture, build, privacy, security, performance, contribution and engine documentation for 0.0.3.

> Publication is complete only when the immutable `ghosium-v0.0.3` release contains verified Setup, Portable and Android APK assets for the exact release commit.

## 0.0.2 — hardening candidate

- Hardened the Windows source-build, updater, installer, benchmark and production-signing contracts.
- Preserved stronger privacy defaults and canonical Setup + Portable provenance requirements.
