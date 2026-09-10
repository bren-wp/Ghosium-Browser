# Changelog

## 0.0.3 — production candidate

- Advanced the active Ghosium Browser product baseline to **0.0.3**.
- Strengthened public product-branding verification so browser-owned runtime UI remains Ghosium Browser / Ghosium / Brendigo.
- Corrected GRIT verification to exclude translator-only `<ex>` metadata while continuing to reject actual runtime Chrome/Chromium browser-brand leaks.
- Added a pinned regression contract that preserves legitimate upstream platform/product names such as `Chromebook` and translator examples without weakening public-brand checks.
- Removed obsolete hardcoded release continuation workflows from the previous baseline and retained fail-closed GitHub-only candidate/promotion behavior.
- Synchronized the bundled Ghosium Privacy extension, built-in Store metadata and fail-closed stable update manifest with the active product version.
- Preserved the exact pinned upstream engine source revision and source-built-only canonical release architecture.
- Preserved native Ghosium branding, `ghost://` internal WebUI routing, Windows executable identity and native New Tab integration.
- Preserved stronger privacy defaults for third-party cookies, search suggestions, speculative preloading, remote alternate-error pages and online spelling upload.
- Preserved native Memory Saver and background-app shutdown behavior.
- Preserved Safe Browsing, TLS/certificate validation, sandboxing, site/process isolation, extension trust and update hash/signature/publisher verification.
- Kept the checked-in stable update manifest fail-closed until canonical release evidence and signing gates succeed.
- Kept canonical Setup + Portable packaging, exact-source provenance, runtime/performance evidence and production signing as mandatory publication gates.

> Publication status: **0.0.3 is a production candidate.** It must not be represented as the canonical GitHub production release until the full release workflow succeeds and the immutable release assets are present.
