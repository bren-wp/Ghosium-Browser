# Building Ghosium Browser

## Production build definition

A Ghosium production release is a **full-source Windows build**. A precompiled browser snapshot, a renamed upstream installer, a launcher-only package, or a source-audit result is not a production Ghosium Browser release.

The canonical release workflow is `.github/workflows/full-source-windows-build.yml`. It is intentionally manual and targets the controlled `ghosium-source-builder` Windows x64 runner.

The production chain is fail-closed:

1. validate the Ghosium `VERSION`, bundled component versions, proprietary product license and preserved third-party rights;
2. validate the controlled Windows source-builder host and pinned `depot_tools` revision;
3. verify patch anchors against the exact commit in `ENGINE_SOURCE_REVISION`;
4. bootstrap or reset the Chromium source workspace to that exact source revision;
5. apply the complete Ghosium source transformation, including Ghosium identity, `ghost://` WebUI namespace, Ghosium Search fallback, Windows executable identity and the native Ghosium updater;
6. verify the transformed source and ensure `third_party/` source has not been modified by Ghosium transformations;
7. configure the reviewed Windows x64 GN arguments;
8. compile the technical upstream `chrome` and `mini_installer` targets from source;
9. verify the newly compiled Ghosium binaries and run sandbox-preserving runtime smoke tests;
10. smoke-test the technical Chromium mini-installer only as evidence that the transformed source installer path remains internally coherent;
11. extract the newly built technical `chrome.7z`, verify that its `Ghosium-Browser.exe` hash matches the compiled output, reject `chrome.exe` and standalone maintenance executables, and assemble the canonical Ghosium release stage;
12. on production `main`, Authenticode-sign `Ghosium-Browser.exe` and `Ghosium-Proxy.exe` with the configured Brendigo/Ghosium code-signing certificate;
13. build the public `Ghosium-Browser-Setup.exe` from `installer/ghosium.nsi` using pinned NSIS 3.12;
14. prove that the public Setup is **not** a renamed `mini_installer.exe`;
15. on production `main`, Authenticode-sign the public Setup and prove that browser, proxy and Setup use the same publisher subject;
16. run the canonical installed round trip: install → runtime smoke → `/S /UPDATE /DELETESELF` → profile/language preservation → runtime smoke → `/S /UNINSTALL` → cleanup verification;
17. generate a production update manifest bound to the exact signed Setup SHA-256 and byte size;
18. generate provenance records and `SHA256SUMS.txt`;
19. upload verified workflow artifacts;
20. on `main`, create a new immutable `ghosium-v0.x.y` GitHub release only if all previous gates succeeded and the tag does not already exist.

A release must not be described as verified or production-ready merely because these steps exist in source. The full-source Windows workflow must actually complete successfully for the exact release commit.

## Source and toolchain pins

The production source toolchain is controlled by:

- `ENGINE_SOURCE_REVISION` — exact browser-engine source commit;
- `DEPOT_TOOLS_REVISION` — exact `depot_tools` commit required by the pinned Chromium DEPS entry;
- `engine/build/windows-x64.args.gn` — reviewed Windows x64 build configuration;
- `scripts/verify-source-builder-host.ps1` — controlled-builder preflight;
- `scripts/verify-pinned-source-anchors.py` — lightweight compatibility check before an expensive source build.

`ENGINE_REVISION` is retained only for historical snapshot/source provenance checks. Stable Ghosium releases are not produced from a precompiled snapshot.

## Canonical public package versus technical build artifacts

The upstream GN/Ninja graph still uses internal names such as `chrome`, `mini_installer`, `chrome.dll`, `chrome_elf.dll` and `chrome.7z`. These remain technical implementation dependencies and must not be presented as public Ghosium identity.

The public Windows executable contract is:

- `Ghosium-Browser.exe` — primary browser executable;
- `Ghosium-Proxy.exe` — Windows proxy/PWA helper;
- `Ghosium-Browser-Setup.exe` — canonical public install/update/uninstall package.

The source-built `mini_installer.exe` is **not** the public Ghosium installer. It remains a technical source-build target because Chromium uses it to produce the source-runtime archive and installer internals required for verification. The public Setup is built separately from the verified source runtime by `scripts/build-source-release-installer.ps1` and `installer/ghosium.nsi`.

The stable GitHub release does not publish the raw technical `chrome.7z` runtime archive as an end-user product artifact.

Do not globally rename remaining upstream DLL, archive or GN target names without a coordinated compile/runtime migration. Such a rename is complete only after dependency resolution, process spawning, DLL loading, installer logic, sandbox/crash integration and runtime behavior have all been rebuilt and verified.

## Native updater and same-Setup maintenance

The Windows About page uses the Ghosium native updater integrated into the pinned browser source. It does not depend on Google Update, a shell script, `curl.exe`, `update.exe`, `updater.exe`, or another standalone maintenance process.

The stable updater contract is:

1. request `https://updates.ghosium.com/windows/stable.json` with browser networking and omitted credentials;
2. require the expected schema, product, Windows platform and stable channel;
3. require a version newer than the installed Ghosium product version;
4. require the Setup URL to remain on the trusted Ghosium update host;
5. download only `Ghosium-Browser-Setup.exe` within the configured maximum size;
6. verify exact byte size and SHA-256;
7. require Authenticode verification and the expected signed publisher relationship;
8. launch the verified Setup using `/S /UPDATE /DELETESELF`.

The same Setup package is also registered for `/UNINSTALL`. Ghosium deliberately does not ship a separate `uninstall.exe` or updater executable.

The repository baseline `updates-web/windows/stable.json` remains disabled/fail-closed. An enabled production manifest is generated only from a verified canonical Setup. On production `main`, `scripts/generate-update-manifest.ps1` requires Authenticode verification before it writes the enabled manifest used as release evidence.

## Production code signing

Production `main` releases require the builder account to have access to the selected Authenticode certificate and its private key. The workflow passes:

- `GHOSIUM_SIGN_CERT_THUMBPRINT` from GitHub Actions secrets;
- `GHOSIUM_TIMESTAMP_URL` from GitHub Actions variables.

`GHOSIUM_SIGN_CERT_THUMBPRINT` must identify a valid certificate in either `Cert:\CurrentUser\My` or `Cert:\LocalMachine\My`. The builder account must be able to use its private key. The signing script uses the pinned Windows SDK `signtool.exe`, SHA-256 file digests and an RFC3161 timestamp.

Do not store a PFX, private key, signing password or other signing secret in the repository. If the certificate is hardware-backed or managed by an external signing service, the controlled runner still needs a signing interface that satisfies the same fail-closed certificate/publisher checks.

## Windows source-builder requirements

The full-source workflow targets a runner labelled:

```text
self-hosted
Windows
X64
ghosium-source-builder
```

The builder must pass `scripts/verify-source-builder-host.ps1` before any source checkout/build is trusted. Persistent workspaces are reset to the pinned dependency state before use.

The source tree and build output require substantially more disk space, memory and build time than a historical snapshot package. Do not weaken verification to make a constrained builder appear healthy. Detailed machine provisioning is documented in `docs/SOURCE_BUILDER_SETUP.md`.

## Local source build

Use repository scripts rather than reproducing ad-hoc commands:

```powershell
./scripts/verify-source-builder-host.ps1
./scripts/bootstrap-engine-source.ps1 -Destination <work-root>
./scripts/apply-engine-branding.ps1 -SourceRoot <work-root>\src
./scripts/verify-engine-fork.ps1 -SourceRoot <work-root>\src
./scripts/verify-engine-windows-executable.ps1 -SourceRoot <work-root>\src
./scripts/verify-engine-version-updater.ps1 -SourceRoot <work-root>\src
./scripts/configure-engine-build.ps1 -SourceRoot <work-root>\src -OutDir out/Ghosium
```

After compilation, run the same verification, source-stage assembly, canonical Setup packaging and smoke sequence used by CI. A local binary must not be called a stable release unless the corresponding production workflow also succeeds for the exact release commit.

## Release evidence

The full-source workflow produces evidence including:

- `GHOSIUM-BUILDER-READY.json` — builder/toolchain preflight;
- `GHOSIUM-SOURCE-BUILD.json` — source-built binary provenance and runtime verification;
- `GHOSIUM-UPSTREAM-MINI-INSTALLER-SMOKE.json` — technical source-installer round trip;
- `GHOSIUM-SOURCE-STAGE.json` — verified source-runtime extraction/staging evidence;
- `GHOSIUM-PUBLIC-SETUP.json` — canonical public Setup identity, maintenance and signing evidence;
- `GHOSIUM-CANONICAL-SETUP-SMOKE.json` — public install/update/uninstall and profile-preservation smoke evidence;
- `GHOSIUM-UPDATE-MANIFEST.json` — production update metadata for the exact signed Setup on `main`;
- `GHOSIUM-LICENSE.txt` and `THIRD_PARTY_NOTICES.md` — release legal payload;
- `SHA256SUMS.txt` — SHA-256 coverage for the verified artifact set.

## Performance measurement

Use `scripts/benchmark-ghosium-windows.ps1` for comparable Windows startup/resource measurements. The benchmark uses the launcher's validated `--ghosium-portable-profile` control to isolate profiles without bypassing the launcher's profile-security boundary.

The benchmark reports startup time, RAM, process/handle count, CPU, disk transfer counters and active TCP connections. It intentionally does not claim measurements that the implementation cannot gather reliably.

## Legal and security requirements

Brendigo-authored proprietary portions of Ghosium Browser are governed by the Brendigo Proprietary Commercial Software License Agreement in `LICENSE`, unless a separate written license explicitly states otherwise. Production release payloads include a verified copy as `GHOSIUM-LICENSE.txt`.

Chromium and all other third-party/open-source components remain governed by their respective licenses. `THIRD_PARTY_NOTICES.md`, upstream copyright notices and other required license material must not be removed or rewritten as Ghosium ownership. The proprietary Ghosium license cannot narrow rights granted directly by third-party licenses.

Performance, branding and packaging work must preserve sandboxing, site isolation, certificate validation and other browser security invariants.
