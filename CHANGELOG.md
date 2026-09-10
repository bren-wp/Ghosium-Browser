# Changelog

## 0.0.2 — production candidate

- Advanced the clean Ghosium product baseline to **0.0.2**.
- Integrated the installer lifecycle hardening and complete public-branding audit already landed on `main`.
- Synchronized the bundled Ghosium Privacy extension, built-in Store metadata and fail-closed stable update manifest with the active product version.
- Made repository source-transformation line endings deterministic across Windows and Linux CI runners.
- Preserved the exact pinned Chromium source revision and source-built-only canonical release architecture.
- Preserved native Ghosium branding, `ghost://` internal WebUI routing, Windows executable identity and the native New Tab integration.
- Preserved stronger privacy defaults for third-party cookies, search suggestions, speculative preloading, remote alternate-error pages and online spelling upload.
- Preserved native Memory Saver and background-app shutdown behavior.
- Preserved Safe Browsing, TLS/certificate validation, sandboxing, site/process isolation, extension trust and update hash/signature/publisher verification.
- Kept the checked-in stable update manifest fail-closed until canonical release evidence and signing gates succeed.
- Kept canonical Setup + Portable packaging, exact-source provenance, runtime/performance evidence and production signing as mandatory publication gates.

> Publication status: **0.0.2 is a production candidate.** It must not be represented as the canonical GitHub production release until the full release workflow succeeds and the immutable release assets are present.
