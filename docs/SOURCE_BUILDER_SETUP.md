# Ghosium Full-Source Windows Builder

This document describes the controlled machine used by `.github/workflows/full-source-windows-build.yml`. The workflow builds the pinned browser engine from source, creates the canonical Ghosium Setup package, performs runtime/install/update/uninstall verification, and on production `main` requires Authenticode signing before release evidence is accepted.

The workflow is intentionally manual and self-hosted. A full Windows browser source checkout and compile is too large and long-running to treat as an ordinary pull-request build.

## Required GitHub Actions labels

Register a Windows x64 self-hosted runner with all four labels:

- `self-hosted`
- `Windows`
- `X64`
- `ghosium-source-builder`

Use GitHub repository **Settings → Actions → Runners → New self-hosted runner** to obtain the current registration command and short-lived registration token. **Do not commit runner tokens**, credentials, PATs, PFX files, private keys, signing passwords, service-account secrets or API keys to this repository.

Install the runner as a Windows service. The service account must have read/write access to the source workspace, enough disk space, access to the required compiler/SDK, and—only for production signing—permission to use the configured code-signing certificate private key.

Keep the service account dedicated to Ghosium builds where practical. Installer smoke tests deliberately refuse unsafe pre-existing test state rather than silently overwriting an unrelated browser installation/profile.

## Pinned Chromium host requirements

The current Ghosium source line pins browser-engine commit `fac978ddceaae0358a2bd69e20a5156ec8dc86ab`. The controlled Windows builder requires:

- x86-64 Windows 10 or newer;
- a 64-bit process on a genuine x64 host;
- at least 8 GiB RAM; 32 GiB or more is recommended;
- NTFS for the source/build workspace;
- at least 120 GiB free for a fresh workspace and 60 GiB when reusing a complete workspace;
- Visual Studio 2026 (18.x or newer);
- **Desktop development with C++** workload;
- ATL/MFC support;
- Windows 11 SDK `10.0.28000.2270`;
- Windows SDK Debugging Tools `10.0.26100.3323` or newer;
- current Git for Windows;
- Chromium `depot_tools` at the front of `PATH`;
- `DEPOT_TOOLS_WIN_TOOLCHAIN=0`;
- `DEPOT_TOOLS_UPDATE=0` during the reproducible workflow;
- `GIT_TERMINAL_PROMPT=0` for unattended operation;
- a short local source path without spaces.

For practical compile times, 16 or more logical processors and a fast SSD are recommended.

## Pinned depot_tools revision

`DEPOT_TOOLS_REVISION` must match the `src/third_party/depot_tools` entry from the **same pinned Chromium DEPS file**. For the current source revision it is:

```text
81577f19a8497ba7e41afac322e8f03553a863ec
```

Install and pin it under a short path, for example:

```powershell
New-Item -ItemType Directory -Force C:\src | Out-Null
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git C:\src\depot_tools
$depotRevision = (Get-Content .\DEPOT_TOOLS_REVISION -Raw).Trim()
git -C C:\src\depot_tools fetch origin $depotRevision --no-tags
git -C C:\src\depot_tools checkout --detach $depotRevision
git -C C:\src\depot_tools reset --hard $depotRevision
```

Verify the exact commit and clean tracked-file state:

```powershell
$expected = (Get-Content .\DEPOT_TOOLS_REVISION -Raw).Trim()
$actual = (git -C C:\src\depot_tools rev-parse HEAD).Trim()
if ($actual -ne $expected) { throw "depot_tools revision mismatch: $actual" }
if (git -C C:\src\depot_tools status --porcelain=v1 --untracked-files=no) {
  throw 'depot_tools tracked files are modified.'
}
```

Put `C:\src\depot_tools` at the front of the runner service account's `PATH` and set:

```powershell
[Environment]::SetEnvironmentVariable('DEPOT_TOOLS_WIN_TOOLCHAIN', '0', 'User')
[Environment]::SetEnvironmentVariable('DEPOT_TOOLS_UPDATE', '0', 'User')
[Environment]::SetEnvironmentVariable('GIT_TERMINAL_PROMPT', '0', 'User')
```

Restart the runner service after changing its environment. If depot_tools initialization modifies the checkout, restore it to the exact `DEPOT_TOOLS_REVISION` and a clean tracked-file state before Ghosium preflight.

## Git configuration

Configure the runner service account:

```powershell
git config --global core.autocrlf false
git config --global core.filemode false
git config --global core.preloadindex true
git config --global core.fscache true
git config --global core.longpaths true
```

The preflight requires `core.autocrlf=false`, `core.filemode=false`, `core.fscache=true`, and `core.longpaths=true`.

## Persistent source workspace

The default persistent workspace is:

```text
C:\src\ghosium-chromium
```

To use another local NTFS drive, configure `GHOSIUM_SOURCE_WORK`, for example:

```powershell
[Environment]::SetEnvironmentVariable('GHOSIUM_SOURCE_WORK', 'D:\src\ghosium-chromium', 'User')
```

The workspace must be either completely empty or a complete reusable checkout containing both `src\.git` and the top-level `.gclient`. A non-empty partial checkout fails preflight. Do not use FAT32/exFAT, a network share, a path with spaces, or a temporary runner directory for the Chromium source workspace.

## Production Authenticode signing

The canonical Setup can be built unsigned for non-production structural/testing workflows, but a stable production `main` release is fail-closed and requires signing.

Install or expose the Ghosium/Brendigo code-signing certificate to the runner service account in one of:

```text
Cert:\CurrentUser\My
Cert:\LocalMachine\My
```

The certificate must:

- have an accessible private key;
- be within its validity period;
- be usable by the runner service account;
- have the publisher identity intended for Ghosium production binaries.

Configure the repository/environment values used by the workflow:

- GitHub Actions secret `GHOSIUM_SIGN_CERT_THUMBPRINT` — the 40-character certificate thumbprint selected for signing;
- GitHub Actions variable `GHOSIUM_TIMESTAMP_URL` — absolute HTTP(S) RFC3161 timestamp endpoint.

The repository stores only the certificate selector/contract. It must never contain the signing private key or PFX password. If a certificate is imported from a PFX, provision that PFX securely outside the repository and restrict private-key permissions to the builder account.

`build-source-release-installer.ps1 -RequireSigning` uses the pinned SDK `signtool.exe` with SHA-256 file digests and RFC3161 timestamping. It signs `Ghosium-Browser.exe`, `Ghosium-Proxy.exe`, then the final `Ghosium-Browser-Setup.exe`. It verifies each signature and requires the Setup publisher subject to match the signed browser publisher subject.

## Builder preflight

Run preflight from a Ghosium repository checkout:

```powershell
$env:DEPOT_TOOLS_WIN_TOOLCHAIN = '0'
$env:DEPOT_TOOLS_UPDATE = '0'
$env:GIT_TERMINAL_PROMPT = '0'
.\scripts\verify-source-builder-host.ps1 `
  -WorkRoot 'C:\src\ghosium-chromium' `
  -ReportPath '.\artifacts\full-source\GHOSIUM-BUILDER-READY.json'
```

The script fails closed on architecture, Visual Studio/SDK, filesystem, disk, Git settings, exact depot_tools revision, workspace completeness or unattended-build invariants. It writes no credentials to the report.

Before an expensive checkout/build, `scripts/verify-pinned-source-anchors.py` also validates the exact source anchors used by Ghosium transformations.

## Running the production full-source workflow

Once the runner is **Online** with the `ghosium-source-builder` label:

1. Open **Actions**.
2. Select **Ghosium Full-Source Windows Build**.
3. Choose **Run workflow** on `main` for a production release candidate.
4. Keep the controlled runner online until the workflow finishes.

A successful workflow must complete all major stages below.

### 1. Build and verify the transformed source

The workflow resets/bootstraps the exact source revision, applies Ghosium transformations, configures the reviewed GN arguments, then compiles:

```text
autoninja -C out/Ghosium chrome mini_installer
```

The `chrome` and `mini_installer` names are technical upstream build-target names. The public executable produced by Ghosium's Windows identity transformation is `Ghosium-Browser.exe`.

`verify-engine-build-output.ps1 -RunRuntimeSmoke` checks product identity, legal payload, install/uninstall source contracts, `ghost://` routes, source provenance and a sandbox-preserving **runtime smoke**.

### 2. Technical source-built installer verification

The source-built installer smoke exercises the technical `mini_installer.exe` installation path because it is part of the upstream source build. It verifies installed runtime behavior and upstream setup-based uninstall behavior. Its evidence is written as:

```text
GHOSIUM-UPSTREAM-MINI-INSTALLER-SMOKE.json
```

This technical mini-installer is not published as the public Ghosium Setup package.

### 3. Assemble the canonical Ghosium source stage

`scripts/assemble-source-release-stage.ps1` extracts the newly generated technical `chrome.7z` using the pinned Chromium 7za binary. It requires the archived `Ghosium-Browser.exe` hash to match the compiled browser output, rejects `chrome.exe`, rejects standalone updater/uninstaller executable names, preserves the required source-runtime layout, and adds the Ghosium license and third-party notices.

Evidence:

```text
GHOSIUM-SOURCE-STAGE.json
```

### 4. Build and sign the canonical public Setup

`scripts/build-source-release-installer.ps1` builds:

```text
Ghosium-Browser-Setup.exe
```

from the verified source stage using `installer/ghosium.nsi` and pinned NSIS 3.12. It explicitly proves that the resulting Setup is not merely a renamed `mini_installer.exe`.

On `main`, the workflow invokes the signing requirement and refuses release if Authenticode verification is not `Valid`.

Evidence:

```text
GHOSIUM-PUBLIC-SETUP.json
```

### 5. Canonical install/update/uninstall round trip

`scripts/smoke-test-windows-installer.ps1` performs the actual public-package maintenance sequence:

1. silent install of `Ghosium-Browser-Setup.exe`;
2. verify installed browser, same-Setup maintenance copy, legal files, registry metadata and no standalone updater/uninstaller;
3. installed browser runtime smoke;
4. create an external profile sentinel;
5. stage the exact canonical Setup in the native updater's private temporary update location;
6. invoke `/S /UPDATE /DELETESELF`;
7. verify downloaded-Setup cleanup, preserved language and preserved external profile;
8. run the installed browser again;
9. invoke the installed same Setup with `/S /UNINSTALL`;
10. require application/registration removal while the normal external profile remains preserved.

Evidence:

```text
GHOSIUM-CANONICAL-SETUP-SMOKE.json
```

### 6. Production update manifest

On `main`, `scripts/generate-update-manifest.ps1 -RequireAuthenticode` creates:

```text
GHOSIUM-UPDATE-MANIFEST.json
```

The manifest is bound to the exact canonical `Ghosium-Browser-Setup.exe` version, SHA-256 and byte size. Production manifest generation requires Windows Authenticode validation first.

The checked-in `updates-web/windows/stable.json` remains a disabled baseline until an independently verified deployment step publishes a production manifest and Setup to the Ghosium update host.

### 7. Release evidence and immutable release

The verified artifact set includes:

```text
Ghosium-Browser-Setup.exe
GHOSIUM-BUILDER-READY.json
GHOSIUM-SOURCE-BUILD.json
GHOSIUM-UPSTREAM-MINI-INSTALLER-SMOKE.json
GHOSIUM-SOURCE-STAGE.json
GHOSIUM-PUBLIC-SETUP.json
GHOSIUM-CANONICAL-SETUP-SMOKE.json
GHOSIUM-UPDATE-MANIFEST.json
GHOSIUM-VERSION.txt
GHOSIUM-LICENSE.txt
THIRD_PARTY_NOTICES.md
SHA256SUMS.txt
```

The raw technical source runtime archive may exist as an internal workflow artifact for diagnosis/provenance, but it is not published as the stable end-user GitHub release asset.

The release job refuses to overwrite an existing `ghosium-v0.x.y` release and independently checks that the update manifest's hash/size match `GHOSIUM-PUBLIC-SETUP.json` before publication.

## Security and reproducibility notes

- Do not commit runner tokens, PATs, signing keys, PFX files, passwords or product API credentials.
- The Ghosium checkout uses `persist-credentials: false` on the persistent builder.
- Keep `DEPOT_TOOLS_REVISION` synchronized with the pinned Chromium DEPS entry.
- Keep `DEPOT_TOOLS_UPDATE=0` during verified builds so the toolchain cannot silently float.
- Keep `GIT_TERMINAL_PROMPT=0` so unattended jobs cannot hang for credentials.
- Do not weaken sandboxing, site isolation, certificate validation, update signature verification or publisher verification to make a build pass.
- `third_party/` source, notices and applicable third-party licenses must remain intact.
- A configured workflow is not evidence of a successful binary release. Production status requires a real successful full-source Windows run and its generated evidence.
