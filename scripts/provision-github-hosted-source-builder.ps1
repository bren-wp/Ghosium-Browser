param(
  [Parameter(Mandatory = $false)]
  [string]$DepotToolsRoot = 'D:\src\depot_tools',

  [Parameter(Mandatory = $false)]
  [string]$WorkRoot = 'D:\src\ghosium-engine',

  [Parameter(Mandatory = $false)]
  [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($env:GITHUB_ACTIONS -ne 'true') {
  throw 'GitHub-hosted source-builder provisioning is restricted to GitHub Actions.'
}
if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
  throw 'GitHub-hosted source-builder provisioning requires Windows.'
}
if (![string]::Equals([Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString(), 'X64', [StringComparison]::OrdinalIgnoreCase)) {
  throw 'GitHub-hosted source-builder provisioning requires Windows x64.'
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$toolchainPath = Join-Path $repoRoot 'engine/build/windows-toolchain.json'
$depotRevisionPath = Join-Path $repoRoot 'DEPOT_TOOLS_REVISION'
foreach ($required in @($toolchainPath, $depotRevisionPath)) {
  if (!(Test-Path $required -PathType Leaf)) {
    throw "Required pinned build contract is missing: $required"
  }
}

$toolchain = Get-Content $toolchainPath -Raw | ConvertFrom-Json
if ([int]$toolchain.schemaVersion -ne 1) {
  throw "Unsupported Windows toolchain contract schema: '$($toolchain.schemaVersion)'"
}
$sdkPackageRevision = ([string]$toolchain.windowsSdkPackageRevision).Trim()
$sdkVersion = ([string]$toolchain.windowsSdkVersion).Trim()
$sdkComponent = ([string]$toolchain.windowsSdkComponent).Trim()
$depotRevision = (Get-Content $depotRevisionPath -Raw).Trim()
if ($depotRevision -notmatch '^[0-9a-f]{40}$') {
  throw "DEPOT_TOOLS_REVISION is invalid: '$depotRevision'"
}

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$installer = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe"
if (!(Test-Path $vswhere -PathType Leaf) -or !(Test-Path $installer -PathType Leaf)) {
  throw 'Visual Studio Installer tooling is missing from the GitHub-hosted Windows image.'
}
$vsPath = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Workload.NativeDesktop Microsoft.VisualStudio.Component.VC.ATLMFC -property installationPath | Select-Object -First 1)
$vsVersion = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Workload.NativeDesktop Microsoft.VisualStudio.Component.VC.ATLMFC -property installationVersion | Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace([string]$vsPath) -or [string]::IsNullOrWhiteSpace([string]$vsVersion)) {
  throw 'GitHub-hosted image does not provide Visual Studio Desktop C++ with ATL/MFC.'
}
if ([int](([string]$vsVersion).Split('.')[0]) -lt [int]$toolchain.visualStudioMajorMinimum) {
  throw "Visual Studio $vsVersion is older than the pinned Ghosium minimum."
}

$kitsRoot = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots' -Name KitsRoot10 -ErrorAction Stop).KitsRoot10
$sdkHeader = Join-Path $kitsRoot "Include\$sdkVersion\um\Windows.h"
$sdkLibrary = Join-Path $kitsRoot "Lib\$sdkVersion\um\x64\Kernel32.Lib"
if (!(Test-Path $sdkHeader -PathType Leaf) -or !(Test-Path $sdkLibrary -PathType Leaf)) {
  Write-Host "Provisioning Windows SDK package $sdkPackageRevision via $sdkComponent"
  $installerArguments = @(
    'modify',
    '--installPath', "`"$vsPath`"",
    '--quiet',
    '--force',
    '--norestart',
    '--add', $sdkComponent
  )
  $installerProcess = Start-Process `
    -FilePath $installer `
    -ArgumentList $installerArguments `
    -Wait `
    -PassThru
  if ($installerProcess.ExitCode -notin @(0, 3010)) {
    throw "Visual Studio Installer failed to provision $sdkComponent with exit code $($installerProcess.ExitCode)"
  }
  if ($installerProcess.ExitCode -eq 3010) {
    Write-Warning 'Visual Studio Installer reported success with reboot required; continuing only because the exact SDK files are verified below.'
  }
}
if (!(Test-Path $sdkHeader -PathType Leaf) -or !(Test-Path $sdkLibrary -PathType Leaf)) {
  throw "Windows SDK package $sdkPackageRevision did not produce required toolchain folder $sdkVersion."
}

$depotToolsResolved = [IO.Path]::GetFullPath($DepotToolsRoot)
$workRootResolved = [IO.Path]::GetFullPath($WorkRoot)
foreach ($path in @($depotToolsResolved, $workRootResolved)) {
  if ($path -match '\s' -or $path -notmatch '^[A-Za-z]:\\') {
    throw "Hosted Chromium build paths must use a local Windows drive without spaces: $path"
  }
}
if ([IO.Path]::GetPathRoot($depotToolsResolved) -ne 'D:\' -or [IO.Path]::GetPathRoot($workRootResolved) -ne 'D:\') {
  throw 'Standard GitHub-hosted Windows builds must use D: for Chromium/depot_tools capacity.'
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $depotToolsResolved) | Out-Null
if (Test-Path $depotToolsResolved) {
  Remove-Item $depotToolsResolved -Recurse -Force
}
& git clone --filter=blob:none --no-checkout https://chromium.googlesource.com/chromium/tools/depot_tools.git $depotToolsResolved
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to clone official Chromium depot_tools.'
}
& git -C $depotToolsResolved fetch origin $depotRevision --no-tags --depth=1
if ($LASTEXITCODE -ne 0) {
  throw "Unable to fetch pinned depot_tools revision $depotRevision"
}
& git -C $depotToolsResolved checkout --detach $depotRevision
if ($LASTEXITCODE -ne 0) {
  throw "Unable to checkout pinned depot_tools revision $depotRevision"
}
& git -C $depotToolsResolved reset --hard $depotRevision
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to reset pinned depot_tools checkout.'
}
$actualDepotRevision = (& git -C $depotToolsResolved rev-parse HEAD).Trim()
$actualOrigin = (& git -C $depotToolsResolved remote get-url origin).Trim().TrimEnd('/')
if ($actualDepotRevision -ne $depotRevision) {
  throw "Pinned depot_tools checkout mismatch: expected $depotRevision; found $actualDepotRevision"
}
if ($actualOrigin -notin @(
  'https://chromium.googlesource.com/chromium/tools/depot_tools.git',
  'https://chromium.googlesource.com/chromium/tools/depot_tools'
)) {
  throw "Unexpected depot_tools origin: $actualOrigin"
}

# PowerShell prefers an application (.exe) over a batch wrapper with the same
# command name even when the batch wrapper's directory appears earlier in PATH.
# GitHub-hosted images add a toolcache python3.exe, while Chromium's pinned
# depot_tools intentionally provides its own python3 wrapper. Remove only PATH
# entries that expose a competing python3.exe so both PowerShell and native
# Windows command resolution are bound to the pinned depot_tools checkout.
$originalPathEntries = @($env:PATH -split ';' | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
$sanitizedPathEntries = New-Object System.Collections.Generic.List[string]
foreach ($entry in $originalPathEntries) {
  $trimmedEntry = $entry.Trim()
  if ([string]::IsNullOrWhiteSpace($trimmedEntry)) {
    continue
  }
  $entryFullPath = $null
  try {
    $entryFullPath = [IO.Path]::GetFullPath($trimmedEntry).TrimEnd('\')
  } catch {
    $sanitizedPathEntries.Add($trimmedEntry)
    continue
  }
  if ([string]::Equals($entryFullPath, $depotToolsResolved.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
    continue
  }
  $competingPython = Join-Path $entryFullPath 'python3.exe'
  if (Test-Path $competingPython -PathType Leaf) {
    Write-Host "Excluding competing python3.exe PATH entry from reproducible Chromium toolchain: $entryFullPath"
    continue
  }
  $sanitizedPathEntries.Add($trimmedEntry)
}
$env:PATH = "$depotToolsResolved;$($sanitizedPathEntries -join ';')"
$env:DEPOT_TOOLS_WIN_TOOLCHAIN = '0'
$env:DEPOT_TOOLS_UPDATE = '0'
$env:GIT_TERMINAL_PROMPT = '0'
$env:GHOSIUM_SOURCE_WORK = $workRootResolved
$env:vs2026_install = [string]$vsPath

$python3Command = Get-Command python3 -ErrorAction SilentlyContinue | Select-Object -First 1
if (!$python3Command -or [string]::IsNullOrWhiteSpace([string]$python3Command.Source)) {
  throw 'Pinned depot_tools python3 wrapper is not resolvable after hosted PATH sanitization.'
}
$python3Path = [IO.Path]::GetFullPath([string]$python3Command.Source)
if (!$python3Path.StartsWith($depotToolsResolved.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
  throw "python3 must resolve from pinned depot_tools after hosted provisioning. Found: $python3Path"
}

& git config --global core.autocrlf false
& git config --global core.filemode false
& git config --global core.fscache true
& git config --global core.longpaths true
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to configure Git for the Chromium hosted builder.'
}

if (Test-Path $workRootResolved) {
  $items = @(Get-ChildItem $workRootResolved -Force -ErrorAction Stop)
  if ($items.Count -gt 0) {
    throw "Hosted source workspace must be fresh-empty before preflight: $workRootResolved"
  }
} else {
  New-Item -ItemType Directory -Force -Path $workRootResolved | Out-Null
}

if (![string]::IsNullOrWhiteSpace($env:GITHUB_PATH)) {
  $depotToolsResolved | Out-File -FilePath $env:GITHUB_PATH -Append -Encoding utf8
}
if (![string]::IsNullOrWhiteSpace($env:GITHUB_ENV)) {
  foreach ($entry in @(
    "PATH=$($env:PATH)",
    "DEPOT_TOOLS_WIN_TOOLCHAIN=0",
    "DEPOT_TOOLS_UPDATE=0",
    "GIT_TERMINAL_PROMPT=0",
    "GHOSIUM_SOURCE_WORK=$workRootResolved",
    "vs2026_install=$vsPath"
  )) {
    $entry | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
  }
}

$drive = Get-PSDrive -Name 'D' -ErrorAction Stop
$report = [ordered]@{
  schemaVersion = 1
  status = 'provisioned'
  provider = 'github-hosted-windows'
  imageOS = [string]$env:ImageOS
  imageVersion = [string]$env:ImageVersion
  visualStudioVersion = [string]$vsVersion
  windowsSdkPackageRevision = $sdkPackageRevision
  windowsSdkVersion = $sdkVersion
  windowsSdkComponent = $sdkComponent
  depotToolsOrigin = $actualOrigin
  depotToolsRevision = $actualDepotRevision
  depotToolsRoot = $depotToolsResolved
  python3Path = $python3Path
  workRoot = $workRootResolved
  freeDiskGiBAfterProvisioning = [math]::Floor($drive.Free / 1GB)
}
if (![string]::IsNullOrWhiteSpace($ReportPath)) {
  $reportPathResolved = [IO.Path]::GetFullPath($ReportPath)
  $directory = Split-Path -Parent $reportPathResolved
  if ($directory) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  [IO.File]::WriteAllText(
    $reportPathResolved,
    (($report | ConvertTo-Json -Depth 6) + "`n"),
    [Text.UTF8Encoding]::new($false)
  )
}

Write-Host 'GitHub-hosted Ghosium source-builder provisioning: OK'
Write-Host "Visual Studio: $vsVersion"
Write-Host "Windows SDK package/toolchain: $sdkPackageRevision / $sdkVersion"
Write-Host "depot_tools: $actualDepotRevision"
Write-Host "python3: $python3Path"
Write-Host "Workspace: $workRootResolved"
Write-Host "D: free after provisioning: $($report.freeDiskGiBAfterProvisioning) GiB"
