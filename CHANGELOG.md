# Changelog

## 0.1.2 — localization, cleanup, performance and stability

### Product identity
- Tightened the Ghosium public/distributable brand contract so legacy upstream browser names cannot appear in Ghosium-owned UI, Setup, Search, Store, update web surfaces or public executable identity.
- Required third-party attribution remains isolated to dedicated legal/license material and is not product branding.
- Kept the `ghost://` / `ghost-untrusted://` internal product namespace contract.

### Languages
- Expanded the supported product locale contract from 30 to **38 languages**.
- English (`en-US`) remains the primary/default locale.
- Croatian (`hr`) remains required and is explicitly selectable in Windows Setup.
- Added Serbian, Catalan, Estonian, Latvian, Lithuanian, Indonesian, Thai and Vietnamese.
- Added localized Ghosium-owned Profile copy instead of forcing the English label into every translated resource bundle.
- Windows Setup now mirrors the browser locale list and initializes the native browser locale on a fresh install without overwriting an existing language preference during reinstall/update.
- Added a dedicated locale CI contract that fails if browser and Setup locale lists diverge.

### Performance and shutdown
- Enabled the engine's native Memory Saver state by default for profiles that have not explicitly selected another state.
- Preserved native medium aggressiveness, tab-freezing behavior, existing discard threshold and explicit user preference precedence.
- Disabled legacy background-app keep-alive in the Windows build configuration so closing the final browser window does not intentionally keep that mode resident.
- Added a pinned-source performance-default contract that applies the transformation twice, independently verifies it and rejects renderer caps or security-reducing launch shortcuts.
- Performance claims remain blocked until the actual 0.1.2 source-built binary is benchmarked against the retained historical methodology.

### Repository cleanup
- Removed the retired pre-source wrapper launcher and its resource/build script.
- Removed the unsupported legacy Portable installer instead of maintaining a second packaging path without source-built parity.
- Removed the obsolete Portable release-bundle Dockerfile and an internal chat-handoff document.
- Canonical Windows distribution remains `Ghosium-Browser-Setup.exe`, which handles install, update and uninstall itself.

### Build and release
- Advanced `VERSION`, Ghosium Privacy, Ghosium Search and built-in Store metadata to `0.1.2`.
- Kept the production full-source build, runtime verification, canonical Setup packaging, signing, update-manifest binding and immutable release evidence as mandatory release gates.

> `0.1.2` is not considered a released source-built browser until the controlled full-source Windows workflow compiles, signs and runtime-tests the exact production commit.

## 0.1.1 — Ghosium-only public surfaces

### Branding and identity
- Completed screenshot-facing Settings/About branding and canonical Ghosium logo integration.
- Replaced browser-owned help and Store entry points with Ghosium-controlled destinations.
- Expanded branding through generic Settings resources and the original 30-locale product set.

### Removed unowned product surfaces
- Removed external browser-account navigation and kept only local Profile surfaces.
- Removed unowned AI navigation and dynamic re-enable paths.
- Removed upstream New Tab customization entry points and hid compatibility-sensitive external browser actions.
- Removed the external Store tile from New Tab/App Launcher while retaining Ghosium Store.
- Disabled mobile acquisition/promotional surfaces because Ghosium does not currently ship a mobile browser.

### Verification
- Added pinned-source public-surface transformation and independent verification.
- Public-surface transformations remain forbidden from modifying `third_party` source.

## 0.1.0 — new Ghosium product line

### Release architecture
- Reset the Ghosium product line to `0.1.0` while preserving historical release provenance.
- Introduced the independent immutable `ghosium-v0.x.y` tag namespace.
- Replaced the historical precompiled snapshot release path with a full-source Windows production gate.
- Added build/runtime verification, provenance, SHA-256 manifests and immutable release checks.

### Performance baseline
- Added a Windows benchmark harness for cold/warm startup, first usable window, RAM, processes, handles, CPU, disk transfer counters and active TCP connections.
- Added one-, five- and ten-tab scenarios plus a one-minute idle memory sample.
- Added a hosted immutable historical baseline artifact with exact SHA-256 verification.

### Product contract
- Added an independent Ghosium product-version contract for About/version surfaces.
- Added coordinated Windows public executable, proxy, Setup, registry and shell identity migration.
- Technical engine build identifiers remain implementation dependencies until a coordinated replacement is proven by successful compile/runtime testing; they are not accepted as public Ghosium branding.

### Licensing and attribution
- Brendigo-authored proprietary portions are governed by the Brendigo Proprietary Commercial Software License Agreement.
- All third-party/open-source components remain governed by their respective licenses.
- Production payloads must carry verified Ghosium license and third-party notice files covered by release SHA-256 evidence.

## Historical development line

The entries below describe the pre-0.1.x development line and are retained in neutral product terminology for provenance.

## 0.8.0
- Hardened installer-tool bootstrap and release verification.
- Added pinned source/build-tool provenance and self-hosted source-builder readiness checks.
- Added source branding, Windows identity, Search, locale and product-link verification.
- Added runtime and installer verification tooling and SHA-256 provenance reports.

## 0.7.0
- Added Ghosium-only New Tab and product navigation.
- Added shared-hosting Ghosium Store source.
- Expanded Setup language chooser to 30 languages with English default and Croatian included.
- Preserved sandbox, certificate validation and process isolation.
- Historical packaging still included Setup and Portable artifacts.

## 0.6.0
- Introduced the early desktop distribution and native wrapper architecture.
- Added Ghosium Search shared-hosting source, privacy rules and an early low-memory mode.
- Added historical Setup/Portable build verification.
