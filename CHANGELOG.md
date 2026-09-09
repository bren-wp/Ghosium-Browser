# Changelog

## 0.1.10 — GitHub-hosted source-builder parity hardening

### Hosted builder and toolchain
- Fixed GitHub-hosted Chromium helper resolution so `fetch`, `gclient`, `gn` and `autoninja` are required to come from the exact pinned `depot_tools` checkout.
- Verified 64-bit Python 3 independently from `depot_tools`; the pinned tools revision does not provide its own `python3` wrapper.
- Centralized the Windows Visual Studio/ATL/MFC, SDK and Debugging Tools requirements in `engine/build/windows-toolchain.json` and aligned Source Builder CI with that single semantic contract.
- Kept hosted parity fail-closed on pinned source/build-tool revisions, NTFS workspace, free-space requirements and required Windows tooling.
- Serialized hosted parity probes so stale runs do not compete for Windows capacity or obscure the newest evidence.

### Release safety
- Advanced `VERSION`, bundled Ghosium Privacy metadata, Store metadata and the disabled Windows update baseline to `0.1.10`.
- Kept the checked-in updater fail-closed (`enabled:false`, empty SHA-256, zero package size) until a real verified signed Setup exists.
- Production source-builder migration remains prohibited until GitHub-hosted parity is fully green and the existing compile, runtime, performance, installer, Authenticode, update, provenance and immutable-release gates can be preserved.

> `0.1.10` is not a source-built production release until the controlled Windows candidate and production workflows compile, runtime-test, measure, sign and package the exact production commit.

## 0.1.9 — Ghosium UI, real README imagery and canonical Portable

### Product UI and branding
- Added Ghosium-owned New Tab, Customize/Options and Ghosium Privacy surfaces with local accent, compact-layout, navigation/status and reduced-effects preferences.
- Added generated Ghosium extension icons and branded NSIS header/welcome artwork while retaining existing installer security behavior.
- Connected the native public-surface and performance-default rewrite/verification steps to the normal source-branding pipeline so those source changes are no longer dormant helpers.

### README and evidence
- Added the Ghosium browser mark to README and synchronized active documentation to 0.1.9.
- Added actual pinned-Chromium renders of the checked-in Ghosium New Tab, Options and Privacy surfaces plus `GHOSIUM-SCREENSHOTS.json` provenance.
- The screenshots are explicitly not presented as canonical full-source browser-shell evidence; that claim remains gated on the controlled Windows source build.

### Setup and Portable
- Added canonical `Ghosium-Browser-Portable.exe` generation from the same verified source stage as Setup, using an adjacent `Ghosium-Portable-Data` profile and no install registration or shortcuts.
- Extended package provenance to schema v3 with Portable filename, byte size, SHA-256 and behavioral guarantees.
- Production signing now requires Valid Authenticode for both Setup and Portable, with the same expected publisher relationship as the signed browser.
- Full-source SHA-256 generation and immutable release publication now require and publish both public EXE packages.

### Performance comparison
- Added `BRZINA.md` and same-run Windows browser comparison tooling for Ghosium, Chrome, Edge, Firefox, Brave, Vivaldi and Opera. Numerical claims remain prohibited until the browsers are actually measured under the documented common methodology.

> `0.1.9` is not a source-built production release until the controlled Windows candidate and production workflows compile, runtime-test, measure, sign and package the exact production commit.

## 0.1.8 — repository hygiene and release-state consistency

### Repository hygiene
- Added a fail-closed Repository Hygiene Contract covering Google Search, retired Search paths, release orchestration and the checked-in Windows update baseline.
- Locked New Tab to direct `https://www.google.com/search` submission and rejects restoration of `search-provider/`, `search-web/` or retired Search migration/CI files.
- Rejects restoration of the legacy snapshot-based stable release workflow and stale fixed-version 0.1.4/0.1.5 release-dispatch references.
- Requires the checked-in stable update baseline to remain disabled, version-synchronized, with an empty SHA-256 and zero package size until a verified production package exists.

### Documentation and versioning
- Advanced `VERSION`, Ghosium Privacy, built-in Store metadata and the fail-closed Windows update baseline to `0.1.8`.
- Synchronized README, build instructions and production release procedure with the Google Search architecture and exact-SHA candidate promotion policy.
- Removed stale active-release documentation that still referenced 0.1.5/0.1.6 or the retired Search Shared Hosting Contract.

> `0.1.8` is not a source-built release until the controlled Windows candidate and production workflows compile, measure, runtime-test, sign and package the exact production commit.

## 0.1.7 — release-marker promotion hardening

### Candidate evidence
- Added a Release Marker Promotion Contract for same-version release-marker-only PRs.
- Same-version marker PRs are accepted only from the exact `ghosium/release/<VERSION>` branch and only when the matching `.release/ghosium-v<VERSION>.request` file is the sole change.
- Marker promotion requires a completed/success full-source candidate run for the exact PR head SHA.
- Candidate promotion downloads and validates the exact candidate evidence bundle, SHA-256 manifest, Setup provenance and performance evidence.

### Release orchestration
- Kept candidate dispatch separate from production `main` publication.
- Preserved mandatory production Authenticode signing and exact update-manifest binding.
- Removed the retired `ghosium/0.1.1-public-branding` trigger from the canonical release contract.
- Kept the checked-in Windows update baseline fail-closed and synchronized to the development version.

## 0.1.6 — Google Search default and Search stack removal

### Search simplification
- Switched the browser and New Tab default web search experience to Google Search.
- Removed the bundled Ghosium Search provider extension and the complete first-party search web service.
- Removed Search-only deployment documentation and CI that no longer represent the product architecture.
- Preserved Chromium's reviewed Google fallback instead of maintaining a custom default-search source patch, reducing source delta and maintenance risk.
- Preserved explicit user search-engine choices, enterprise policy and extension override precedence.

### Code quality and privacy
- Removed stale Search metadata from product URL allowlists and the built-in Store catalog.
- Kept Ghosium Privacy declarative tracker protection independent from search-provider removal.
- Updated public-surface CI so `www.google.com` is allowed only for the intentional New Tab search action while Ghosium-controlled product links remain restricted to approved first-party hosts.
- Advanced the browser, bundled Ghosium Privacy component and fail-closed update baseline to 0.1.6; the stable updater remains disabled until a real signed production package exists.

## 0.1.5 — release orchestration and candidate safety

### Release orchestration
- Replaced the fixed 0.1.4 release dispatcher with a version-bound candidate workflow.
- Candidate requests run only from `ghosium/release/<VERSION>` and must match `VERSION`.
- Exactly one `.release/ghosium-v<version>.request` marker may be active for a candidate.
- Candidate dispatch refuses an already-published immutable release tag.
- Merging a candidate marker into `main` no longer automatically dispatches production; production remains a separate explicit gate after successful candidate evidence.

### Version and update safety
- Advanced `VERSION`, Ghosium Privacy, Ghosium Search, built-in Store metadata and the disabled Windows stable update baseline to `0.1.5`.
- Retired the stale 0.1.4 request marker and created the version-bound `ghosium-v0.1.5` request.
- Kept checked-in Windows stable update metadata fail-closed (`enabled:false`) with empty SHA-256 and zero size until the exact signed production Setup exists.

### Product baseline
- Carries forward the 0.1.4 native `ghost://profiles/` and `ghost://passwords/` controller routing, 38-locale contract, Search hardening, native performance defaults, source-built benchmark evidence, canonical same-Setup maintenance and production signing requirements.
- Hosted CI and release metadata remain preparation only. Ghosium 0.1.5 must not be described as source-built, signed, update-ready or released until the controlled Windows full-source candidate and production gates complete successfully.

## 0.1.4 — native internal hosts and source-contract hardening

### Native Ghosium WebUI
- Promoted `ghost://profiles/` from a redirect shim to the canonical host used by the existing native profile-picker WebUI controller.
- Promoted `ghost://passwords/` from a redirect shim to the canonical host used by the native password-manager WebUI controller.
- Removed the former `browser_about_handler.cc` redirects to Settings/manageProfile and password-manager routes.
- Kept the maintained profile/password controller implementations instead of duplicating security-sensitive logic in parallel Ghosium-only controllers.
- Strengthened `verify-engine-fork.ps1` to require the native host/controller registrations and reject restoration of the old redirects.

### Pinned source compatibility
- Updated Search fallback anchors to the actual pinned `GetPrepopulatedFallbackSearch()` implementation and its reviewed fallback path.
- Updated Windows install-mode anchors to the current `browser_prog_id_*`, PDF ProgID, direct-launch and product/company identity fields used by the pinned source.
- Updated Windows executable/build anchors to the current PE/PDB output, reorder-imports, mini-installer, central filename constants, VisualElements, launcher fallback and proxy build path used by the source transformation.
- Added revision-pinned anchors for the profile-picker and password-manager WebUI registrations used by the new native `profiles` and `passwords` hosts.
- Kept source-anchor changes tied to exact transform inputs instead of weakening the verifier to broad or incidental strings.

### Localization and build documentation
- Tightened source/fork verification to require exactly **38 supported locales** with English (`en-US`) default and Croatian (`hr`) required.
- Aligned `BUILDING.md`, source-builder documentation and release procedure with the actual transform sequence.
- Removed the redundant documented second invocation of the product-version rewrite because `apply-engine-branding.ps1` already applies it as a mandatory transform.
- Kept the controlled Windows full-source build manual/self-hosted and retained sandbox-preserving runtime smoke, source-built performance evidence and signing as release gates.

### Versioning
- Advanced `VERSION`, Ghosium Privacy, Ghosium Search, built-in Store metadata and the disabled Windows update baseline to `0.1.4`.
- The checked-in update baseline remains `enabled:false` with empty SHA-256 and zero size until a real verified signed 0.1.4 Setup exists.

> `0.1.4` is not considered a released source-built browser until the controlled full-source Windows workflow compiles, measures, signs and runtime-tests the exact production commit.

## 0.1.3 — Search redesign, measured performance gate and release hardening

### Ghosium Search
- Rebuilt the public Ghosium Search interface from the ground up around the same dark surface, mint/teal/cyan accent system and compact browser-like controls used by Ghosium Browser.
- Replaced the monolithic public template with reusable server-rendered PHP UI components for brand, search box and result cards.
- Kept the public search path free of a JavaScript runtime bundle: no client framework, hydration layer or Node application server is required to search.
- Removed developer/operator examples, index counts and provider implementation details from the public home page. Users see one focused search box; advanced `site:`, phrase, exclusion, title and explicit `!bang` functionality remains available to the parser/API.
- Added responsive browser-style result layout, accessible controls, reduced-motion handling and no inline CSS/JavaScript.
- Strengthened Search CI so public UI simplicity is a contract while backend advanced-query behavior remains independently tested.

### Performance evidence
- Upgraded the Windows benchmark evidence schema to v2.
- Added direct source-built `UserDataDir` benchmark mode while retaining the historical portable-profile mode for the immutable pre-0.1.0 comparison binary.
- Added best-effort per-process Windows GPU memory counters with explicit unavailable state instead of fabricated zero values.
- Added Ghosium-owned TCP/UDP endpoint snapshots, TCP state counts and unique remote-address counts without misrepresenting them as network-byte attribution.
- Added five-second and sixty-second activity intervals with CPU and process-I/O deltas.
- Made `GHOSIUM-PERFORMANCE.json` mandatory evidence in the controlled full-source Windows build and immutable release gate.

### Builder and release engineering
- Renamed the default persistent source workspace to `C:\src\ghosium-engine`.
- Documented the interactive Windows desktop requirement needed to measure first usable browser window reliably.
- Strengthened the Source Builder contract to parse and validate benchmark tooling and require source-built performance evidence in the manual release workflow.
- Kept all performance work behind sandbox/site-isolation/certificate-validation safety boundaries.

### Versioning
- Advanced `VERSION`, Ghosium Privacy, Ghosium Search, built-in Store metadata and the disabled Windows update baseline to `0.1.3`.
- The checked-in update baseline remains disabled and contains no release SHA-256/size until a real signed 0.1.3 package exists.

> `0.1.3` is not considered a released source-built browser until the controlled full-source Windows workflow compiles, measures, signs and runtime-tests the exact production commit.

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
- Performance claims remain blocked until the actual source-built binary is benchmarked against the retained historical methodology.

### Repository cleanup
- Removed the retired pre-source wrapper launcher and its resource/build script.
- Removed the unsupported legacy Portable installer instead of maintaining a second packaging path without source-built parity.
- Removed the obsolete Portable release-bundle Dockerfile and an internal chat-handoff document.
- Canonical Windows distribution remains `Ghosium-Browser-Setup.exe`, which handles install, update and uninstall itself.

### Build and release
- Advanced `VERSION`, Ghosium Privacy, Ghosium Search and built-in Store metadata to `0.1.2`.
- Kept the production full-source build, runtime verification, canonical Setup packaging, signing, update-manifest binding and immutable release evidence as mandatory release gates.

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
