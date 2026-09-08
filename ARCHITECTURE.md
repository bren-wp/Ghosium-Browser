# Ghosium Browser Architecture

## Scope

Ghosium Browser 0.1.6 is designed as a direct source-built Windows x64 browser product. The production architecture no longer uses a separate wrapper launcher or a second Portable packaging path.

## Runtime and distribution

Public Windows product identity is intentionally small:

```text
Ghosium-Browser.exe
Ghosium-Proxy.exe
Ghosium-Browser-Setup.exe
```

`Ghosium-Browser.exe` is the primary native browser executable produced by the transformed source build. `Ghosium-Proxy.exe` is the compatible helper used where the Windows browser integration requires it. `Ghosium-Browser-Setup.exe` is the single installation/maintenance package.

The Setup package performs install, update and uninstall. There is no separately distributed updater or uninstaller executable.

## Source transformation boundary

The repository does not vendor the complete engine source tree. Instead it stores:

- an exact source revision;
- an exact build-tool revision;
- Ghosium product metadata and artwork;
- reviewed source transformations;
- independent verification scripts;
- deterministic Windows build arguments;
- release and runtime contracts.

The controlled source builder fetches the exact pinned source, applies the Ghosium transformations, verifies the resulting tree, compiles it, tests the runtime and then packages the canonical Setup.

Technical identifiers required by the upstream build API can remain inside engineering tooling until a coordinated replacement is proven by compile/runtime testing. They are not accepted on Ghosium-owned public surfaces.

## Public UI boundary

Ghosium-owned UI uses Ghosium/Brendigo identity and the `ghost://` namespace. Unowned cloud/account/AI/mobile promotional features are removed or made unreachable rather than falsely relabeled.

Primary routes include:

```text
ghost://newtab/
ghost://history/
ghost://bookmarks/
ghost://downloads/
ghost://settings/
ghost://profiles/
ghost://extensions/
ghost://passwords/
```

## Local profile boundary

The canonical per-user profile root is:

```text
%LOCALAPPDATA%\Brendigo\Ghosium\User Data
```

Profiles remain local-first. Browser-level external account onboarding, external Sync promotions and related cloud-profile surfaces are not part of the Ghosium product contract.

Normal sign-in to websites remains ordinary web functionality and is not disabled by the local-profile product policy.

## Languages

Ghosium defines one product locale list in `engine/branding/product.json`. Version 0.1.6 supports 38 locales. English (`en-US`) is the primary/default locale and Croatian (`hr`) is required.

Interactive Setup presents the same locale set. A fresh installation initializes the browser's native application locale from the Setup selection. Existing browser locale preferences are not overwritten by maintenance updates or reinstalls.

## Search and first-party web services

Ghosium does not operate or bundle a first-party web search service. The browser default and New Tab search use Google Search as an external service and submit queries directly to Google.

The independently deployable Ghosium-controlled shared-hosting services are limited to:

```text
store-web/       store.ghosium.com
updates-web/     updates.ghosium.com
```

These web applications are not linked into the browser executable and can be deployed independently.

## Update trust boundary

The browser-native update flow validates:

1. Ghosium-owned HTTPS endpoint and exact download path;
2. manifest schema/product/platform/channel;
3. strictly newer product version;
4. exact package byte size;
5. SHA-256;
6. Authenticode validity and expected publisher relationship;
7. signed PE product/company/version metadata;
8. canonical same-Setup update mode.

A failed check stops the update before execution.

## Performance model

Performance work uses native source/build mechanisms rather than security-reducing command-line shortcuts.

For 0.1.6:

- native Memory Saver defaults to enabled unless the user explicitly chose another state;
- native medium aggressiveness and tab-freezing semantics are preserved;
- legacy background-app keep-alive is disabled at build configuration level;
- renderer/site isolation and sandboxing remain mandatory;
- the product does not impose a renderer-process cap merely to make RAM numbers look lower.

A source-level optimization is not considered a performance improvement until the compiled binary is benchmarked using the repository methodology.

## Release boundary

Hosted CI proves source-transform, localization, installer, updater and security contracts. It does **not** prove that the final browser binary compiled successfully.

Production status requires the controlled full-source Windows workflow to complete compile, runtime smoke, canonical Setup assembly, signing, install/update/uninstall round trip, provenance and hashes for the exact release commit.

## Legal boundary

Brendigo-authored Ghosium material is governed by the Ghosium product license. Third-party components remain governed by their own terms. Required attribution and notices are kept in dedicated legal/license payloads rather than used as product identity.
