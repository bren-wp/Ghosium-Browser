# Ghosium Full-Source Windows Builder

This document defines the controlled Windows x64 machine used by `.github/workflows/full-source-windows-build.yml`. The workflow builds the pinned engine source, applies the Ghosium fork, compiles the browser, measures the compiled runtime, builds the canonical Ghosium Setup package, performs install/update/uninstall verification and—on production `main`—requires Authenticode signing before an immutable release can be published.

The heavyweight workflow is intentionally manual and self-hosted. A source audit or patch smoke is not a completed browser build.

## Required runner labels

Register a Windows x64 self-hosted runner with all four labels:

- `self-hosted`
- `Windows`
- `X64`
- `ghosium-source-builder`

Use GitHub repository **Settings → Actions → Runners → New self-hosted runner** for the current registration command and short-lived registration token. **Do not commit runner tokens**, PATs, PFX files, private keys, signing passwords, service-account secrets or API keys.

### Interactive desktop requirement

The production workflow now records cold/warm startup to the first usable Ghosium window. Therefore the `ghosium-source-builder` runner used for the release-candidate run must execute in a dedicated, logged-in **interactive Windows desktop session**. Do not run the measurement stage only in Windows Session 0/a non-interactive service desktop, because that environment cannot prove a first usable browser window.

A dedicated build account is recommended. Keep the machine locked down, keep credentials outside the repository, and restrict access to the account and signing material. The browser benchmark itself does not disable sandboxing, site isolation, certificate validation or GPU security.

## Pinned engine host requirements

The current Ghosium source line pins engine commit `fac978ddceaae0358a2bd69e20a5156ec8dc86ab`. The controlled builder requires:

- x86-64 Windows 10 or newer;
- a 64-bit process on a genuine x64 host;
- at least 8 GiB RAM; 32 GiB or more is recommended;
- NTFS for the source/build workspace;
- at least 120 GiB free for a fresh workspace and 60 GiB when reusing a complete workspace;
- Visual Studio 2026 (18.x or newer);
- **Desktop development with C++**;
- ATL/MFC support;
- Windows 11 SDK `10.0.28000.2270`;
- Windows SDK Debugging Tools `10.0.26100.3323` or newer;
- current Git for Windows;
- pinned `depot_tools` at the front of `PATH`;
- `DEPOT_TOOLS_WIN_TOOLCHAIN=0`;
- `DEPOT_TOOLS_UPDATE=0` during verified builds;
- `GIT_TERMINAL_PROMPT=0`;
- a short local source path without spaces.

For practical compile times, 16 or more logical processors and a fast SSD are recommended.

## Pinned depot_tools revision

`DEPOT_TOOLS_REVISION` must match the `src/third_party/depot_tools` entry from the same pinned engine DEPS file. For the current source revision:

```text
81577f19a8497ba7e41afac322e8f03553a863ec
```

Example installation:

```powershell
New-Item -ItemType Directory -Force C:\src | Out-Null
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git C:\src\depot_tools
$depotRevision = (Get-Content .\DEPOT_TOOLS_REVISION -Raw).Trim()
git -C C:\src\depot_tools fetch origin $depotRevision --no-tags
git -C C:\src\depot_tools checkout --detach $depotRevision
git -C C:\src\depot_tools reset --hard $depotRevision
```

Verify the exact revision and clean tracked-file state:

```powershell
$expected = (Get-Content .\DEPOT_TOOLS_REVISION -Raw).Trim()
$actual = (git -C C:\src\depot_tools rev-parse HEAD).Trim()
if ($actual -ne $expected) { throw "depot_tools revision mismatch: $actual" }
if (git -C C:\src\depot_tools status --porcelain=v1 --untracked-files=no) {
  throw 'depot_tools tracked files are modified.'
}
```

Put `C:\src\depot_tools` at the front of the build account's `PATH` and set:

```powershell
[Environment]::SetEnvironmentVariable('DEPOT_TOOLS_WIN_TOOLCHAIN', '0', 'User')
[Environment]::SetEnvironmentVariable('DEPOT_TOOLS_UPDATE', '0', 'User')
[Environment]::SetEnvironmentVariable('GIT_TERMINAL_PROMPT', '0', 'User')
```

Restart/relaunch the runner after changing its environment. If depot_tools initialization modifies tracked files, restore it to the exact `DEPOT_TOOLS_REVISION` before preflight.

## Git configuration

Configure the runner account:

```powershell
git config --global core.autocrlf false
git config --global core.filemode false
git config --global core.preloadindex true
git config --global core.fscache true
git config --global core.longpaths true
```

The preflight requires `core.autocrlf=false`, `core.filemode=false`, `core.fscache=true`, and `core.longpaths=true`.

## Persistent Ghosium engine workspace

The default workspace is:

```text
C:\src\ghosium-engine
```

To use another local NTFS drive, configure `GHOSIUM_SOURCE_WORK`, for example:

```powershell
[Environment]::SetEnvironmentVariable('GHOSIUM_SOURCE_WORK', 'D:\src\ghosium-engine', 'User')
```

The workspace must be completely empty or a complete reusable checkout containing both `src\.git` and the top-level `.gclient`. A non-empty partial checkout fails preflight. Do not use FAT32/exFAT, a network share, a path with spaces or a temporary runner directory for the engine source workspace.

## Production Authenticode signing

The canonical Setup can be built unsigned for non-production structural/testing runs. A stable production `main` release is fail-closed and requires signing.

Expose the Ghosium/Brendigo code-signing certificate to the build account under one of:

```text
Cert:\CurrentUser\My
Cert:\LocalMachine\My
```

The certificate must have an accessible private key, be valid at build time and represent the intended Ghosium publisher identity.

Configure:

- GitHub Actions secret `GHOSIUM_SIGN_CERT_THUMBPRINT` — certificate thumbprint;
- GitHub Actions variable `GHOSIUM_TIMESTAMP_URL` — absolute HTTP(S) RFC3161 timestamp endpoint.

The repository must never contain the private key or PFX password. `build-source-release-installer.ps1 -RequireSigning` signs the Ghosium browser/proxy and final `Ghosium-Browser-Setup.exe`, then verifies the signatures and publisher relationship.

## Builder preflight

From a Ghosium repository checkout:

```powershell
$env:DEPOT_TOOLS_WIN_TOOLCHAIN = '0'
$env:DEPOT_TOOLS_UPDATE = '0'
$env:GIT_TERMINAL_PROMPT = '0'
.\scripts\verify-source-builder-host.ps1 `
  -WorkRoot 'C:\src\ghosium-engine' `
  -ReportPath '.\artifacts\full-source\GHOSIUM-BUILDER-READY.json'
```

The script fails closed on architecture, Visual Studio/SDK, filesystem, disk, Git settings, exact depot_tools revision, workspace completeness or unattended-build invariants. It writes no credentials to the report.

Before the expensive source sync/build, `scripts/verify-pinned-source-anchors.py` validates the exact source anchors used by Ghosium transformations.

## Running the production full-source workflow

Once the interactive runner is online with the `ghosium-source-builder` label:

1. Open **Actions**.
2. Select **Ghosium Full-Source Windows Build**.
3. Choose **Run workflow** on the exact release-candidate commit/branch. Use `main` only when the commit is intended to pass production signing and release publication.
4. Keep the controlled interactive runner online until the workflow completes.

A successful production run must complete every stage below.

### 1. Build and verify transformed source

The workflow resets/bootstraps the exact pinned source revision, applies Ghosium transformations, configures reviewed GN arguments, then compiles:

```text
autoninja -C out/Ghosium chrome mini_installer
```

The target names are upstream technical build-system identifiers. They are not public Ghosium branding. The public Windows executable produced by the fork is `Ghosium-Browser.exe`.

`verify-engine-build-output.ps1 -RunRuntimeSmoke` validates the compiled output and preserves the runtime sandbox.

### 2. Measure the compiled Ghosium runtime

A successful candidate must run:

```text
scripts/benchmark-ghosium-windows.ps1
```

against the newly compiled `out/Ghosium/Ghosium-Browser.exe` with `-ProfileMode UserDataDir`.

Evidence is written as:

```text
GHOSIUM-PERFORMANCE.json
```

The schema records:

- cold startup to first usable window;
- warm startup to first usable window;
- RAM/private/paged memory;
- 1, 5 and 10 tab scenarios;
- process count and handles;
- CPU activity;
- process I/O deltas;
- a 60-second one-tab idle interval;
- best-effort Windows per-process GPU memory counters;
- best-effort Ghosium-owned TCP/UDP endpoint activity.

GPU fields are explicitly marked unavailable when the Windows/driver counter mapping is unavailable. TCP/UDP endpoint activity is not misrepresented as byte-level packet attribution.

Performance work is benchmark-driven. Do not introduce renderer caps, `--no-sandbox`, GPU-sandbox disablement, site-isolation disablement or certificate bypasses to improve numbers.

### 3. Technical source installer verification

The source-built `mini_installer.exe` is exercised only as a technical build-system/install verification input. Its evidence is:

```text
GHOSIUM-UPSTREAM-MINI-INSTALLER-SMOKE.json
```

It is not the public Ghosium installer asset.

### 4. Assemble canonical Ghosium source stage

`scripts/assemble-source-release-stage.ps1` extracts the source-built runtime archive, verifies the archived `Ghosium-Browser.exe` against the compiled binary, rejects legacy public executable names, adds the Ghosium commercial license and required third-party notices, and writes:

```text
GHOSIUM-SOURCE-STAGE.json
```

### 5. Build and sign canonical Setup

`scripts/build-source-release-installer.ps1` builds:

```text
Ghosium-Browser-Setup.exe
```

from the verified stage and proves it is not merely a renamed technical mini-installer. Production `main` requires valid Authenticode evidence:

```text
GHOSIUM-PUBLIC-SETUP.json
```

### 6. Canonical install/update/uninstall round trip

`scripts/smoke-test-windows-installer.ps1` performs the public package maintenance sequence: install, runtime verification, external-profile sentinel, same-Setup update, cleanup verification, language/profile preservation, runtime recheck and same-Setup uninstall.

Evidence:

```text
GHOSIUM-CANONICAL-SETUP-SMOKE.json
```

### 7. Production update manifest

On `main`, `scripts/generate-update-manifest.ps1 -RequireAuthenticode` creates:

```text
GHOSIUM-UPDATE-MANIFEST.json
```

The manifest is bound to the exact canonical Setup version, SHA-256 and byte size. The checked-in update manifest remains fail-closed until an independently verified deployment publishes the exact signed package.

### 8. Immutable release evidence

The verified artifact set includes:

```text
Ghosium-Browser-Setup.exe
GHOSIUM-BUILDER-READY.json
GHOSIUM-SOURCE-BUILD.json
GHOSIUM-PERFORMANCE.json
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

The technical source runtime archive may exist as an internal workflow artifact for provenance/diagnosis but is not a stable end-user release asset.

The release job refuses to overwrite an existing `ghosium-v0.x.y` release and verifies the Setup/update/performance evidence before publication.

## Security and reproducibility rules

- Do not commit runner tokens, PATs, signing keys, PFX files, passwords or product API credentials.
- GitHub checkout on the builder uses `persist-credentials: false`.
- Keep `DEPOT_TOOLS_REVISION` synchronized with the pinned source DEPS entry.
- Keep `DEPOT_TOOLS_UPDATE=0` for verified builds.
- Keep `GIT_TERMINAL_PROMPT=0` for unattended source/build operations.
- Use an interactive desktop only because the release gate measures first usable browser window; do not weaken Windows or browser security to make the benchmark run.
- Keep third-party source/notices/licenses intact where required.
- A configured workflow, successful source audit or passing hosted CI is not evidence of a completed source-built release. Production status requires a real successful full-source Windows compile and its generated evidence for the exact commit.
