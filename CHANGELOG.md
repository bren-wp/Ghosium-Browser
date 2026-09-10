# Changelog

## 0.0.3 — hardening candidate

- Advanced the active development baseline to **0.0.3** without changing the exact pinned Chromium source revision.
- Isolated native updater downloads into unique per-session directories under the secure Windows temporary directory.
- Preserved exact updater host/path/port restrictions, redirect rejection, bounded downloads, SHA-256 verification, same-publisher Authenticode validation and signed PE product/company/version binding.
- Hardened NSIS toolchain discovery so arbitrary user-writable `PATH` entries cannot become trusted release compilers.
- Restricted NSIS fallback downloads to HTTPS-only redirects with bounded transfer time and retained exact SHA-256 pinning.
- Added safe reuse of an already downloaded NSIS archive only after exact size and SHA-256 verification.
- Reworked Ghosium performance benchmarking to refuse pre-existing user sessions and terminate only benchmark-owned launcher process trees.
- Reworked cross-browser comparison cleanup so already-running browsers are skipped instead of force-terminated.
- Replaced repeated whole-system process enumeration in hot benchmark sampling paths with targeted browser process lookup.
- Preserved native Memory Saver and background-app shutdown behavior.
- Preserved stronger privacy defaults for third-party cookies, search suggestions, speculative preloading, remote alternate-error pages and online spelling upload.
- Preserved Safe Browsing, TLS/certificate validation, sandboxing, site/process isolation, extension trust and update hash/signature/publisher verification.
- Kept the checked-in stable update manifest fail-closed until canonical release evidence and signing gates succeed.
- Kept canonical Setup + Portable packaging, exact-source provenance, runtime/performance evidence and production signing as mandatory publication gates.

> Publication status: **0.0.3 is a hardening candidate.** It must not be represented as the canonical GitHub production release until the full release workflow succeeds and immutable release assets are present.
