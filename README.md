# Ghosium Browser

**Ghosium Browser by Brendigo** is a Chromium-derived browser fork for Windows x64. The current product line starts at **0.1.0** and is being developed as a source-built Ghosium product rather than a precompiled upstream snapshot with a renamed launcher.

## Current release contract

The new Ghosium product line uses semantic versions beginning with `0.1.0` and Git tags in the separate namespace:

```text
ghosium-v0.1.0
ghosium-v0.1.1
ghosium-v0.2.0
```

Historical `v0.x.y` tags and releases remain untouched.

A production Ghosium release is publishable only after the pinned full-source Windows workflow succeeds. The release gate requires:

1. exact pinned source checkout;
2. Ghosium fork patches applied to that checkout;
3. source verification;
4. full browser compile;
5. runtime smoke verification;
6. source-built installer install/uninstall smoke verification;
7. provenance reports;
8. SHA-256 manifest generation;
9. immutable `ghosium-v0.x.y` release creation.

A source audit, source patch, or snapshot-based packaging job is **not** treated as proof that Ghosium was built from source.

## Product identity

Ghosium-controlled product surfaces use:

- product: **Ghosium Browser**
- publisher/company: **Brendigo**
- home: `https://ghosium.com/`
- search: `https://search.ghosium.com/`
- store: `https://store.ghosium.com/`
- support: `https://ghosium.com/support`
- security: `https://ghosium.com/security`
- terms: `https://ghosium.com/legal/terms`
- privacy: `https://ghosium.com/legal/privacy-policy`
- licenses: `https://ghosium.com/legal/licenses`

Required third-party licenses, copyright notices, and attribution are preserved. They belong in legal/license surfaces and are not treated as Ghosium product branding.

## Internal Ghosium URLs

The source fork owns the Ghosium internal namespace:

- `ghost://newtab/`
- `ghost://history/`
- `ghost://bookmarks/`
- `ghost://downloads/`
- `ghost://settings/`
- `ghost://profiles/`
- `ghost://extensions/`
- `ghost://passwords/`
- restricted WebUI scheme: `ghost-untrusted://`

The repository contains source rewrite and verifier tooling for this contract. Runtime support is considered verified only when the pinned full-source compile and runtime tests pass.

## Ghosium Search

The default search endpoint is:

```text
https://search.ghosium.com/?q={searchTerms}
```

The bundled search-provider manifest, Store metadata, and browser `VERSION` are required by CI to remain synchronized.

## Ghosium Store

The Ghosium Store destination is:

```text
https://store.ghosium.com/
```

Ghosium-owned extension UI and product links must not send users to an upstream browser store. Extension package trust and signature/security behavior must remain fail-closed.

## Performance work

Performance changes are measurement-driven. The repository includes `scripts/benchmark-ghosium-windows.ps1`, which records:

- cold startup using a fresh profile;
- warm startup using the same profile;
- time to the first usable browser window;
- aggregate working set and private memory;
- one-, five-, and ten-tab process/memory samples;
- one-minute idle memory for the one-tab scenario;
- process count and handle count;
- normalized idle CPU;
- process disk read/write transfer counters;
- active TCP connection count.

`.github/workflows/performance-baseline.yml` benchmarks the immutable historical `v0.8.0` Windows Setup artifact after verifying its SHA-256. That result is the pre-0.1.0 baseline. No new RAM/startup claim should be made until a comparable 0.1.x source-built result exists.

The benchmark explicitly does not claim a true filesystem-cache-flushed cold boot, per-process network byte attribution, or reliable GPU-memory attribution until those measurements are implemented.

## Security invariants

Ghosium performance or privacy work must not disable the browser security architecture. In particular, production code must not globally disable:

- the sandbox;
- renderer sandboxing;
- site isolation;
- certificate validation;
- TLS error handling;
- extension trust verification;
- update trust verification.

The launcher rejects high-risk command-line overrides such as sandbox removal, site-isolation disabling, web-security disabling, broad TLS-error bypasses, and protected remote-debugging changes.

## Windows identity

The source branding pipeline rewrites the pinned Windows install-mode identity to Ghosium/Brendigo values for product path, base application identity, browser ProgID prefix, HTML/PDF document identity, and direct-launch scheme. Technical upstream identifiers that are part of compatibility/security contracts are not renamed blindly.

The canonical user profile path is:

```text
%LOCALAPPDATA%\Brendigo\Ghosium\User Data
```

## Source build

The Windows full-source build uses:

- `ENGINE_SOURCE_REVISION` for the pinned browser source commit;
- `DEPOT_TOOLS_REVISION` for the pinned build tooling;
- `engine/build/windows-x64.args.gn` for the reviewed release configuration;
- `scripts/bootstrap-engine-source.ps1` for source checkout;
- `scripts/apply-engine-branding.ps1` for coordinated Ghosium source changes;
- `scripts/verify-engine-fork.ps1` for source-fork verification;
- `scripts/verify-engine-build-output.ps1` for compiled output/runtime verification;
- `scripts/smoke-test-source-windows-installer.ps1` for source-built install/uninstall verification.

Upstream GN/Ninja target or intermediate artifact names may remain where a coordinated rename has not yet been proven by compile/runtime tests. Such names are build-system dependencies, not accepted public product identity.

## Repository layout

```text
.github/workflows/      CI, source-build, release and regression contracts
engine/                 Ghosium product metadata, branding assets and GN config
extension/              Ghosium Privacy + New Tab component
search-provider/        Ghosium Search provider component
launcher/               native Ghosium Windows launcher
installer/              legacy/bootstrap NSIS packaging support
scripts/                source patching, verification, build and benchmark tooling
search-web/             Ghosium Search web service
store-web/              Ghosium Store web service
docs/                   architecture, security, release and build documentation
```

## Release immutability

Existing releases are never overwritten. If `ghosium-v0.x.y` already exists, the release workflow fails instead of replacing its assets. Every merged production change therefore requires a new product version before another release can be created.

## License

Ghosium-authored source is licensed under the BSD 3-Clause License in `LICENSE`. Copyright holder/publisher: **Brendigo**. Third-party components keep their original licenses and required notices.
