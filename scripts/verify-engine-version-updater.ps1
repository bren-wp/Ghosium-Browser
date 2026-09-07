param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedCommit = (Get-Content (Join-Path $repoRoot 'ENGINE_SOURCE_REVISION') -Raw).Trim()
$productVersion = (Get-Content (Join-Path $repoRoot 'VERSION') -Raw).Trim()
$sourceRootResolved = (Resolve-Path $SourceRoot).Path

$actualCommit = (& git -C $sourceRootResolved rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualCommit -ne $expectedCommit) {
  throw "Updater verification requires pinned Chromium $expectedCommit; found $actualCommit"
}

$buildPath = Join-Path $sourceRootResolved 'chrome/browser/ui/webui/help/BUILD.gn'
$sourcePath = Join-Path $sourceRootResolved 'chrome/browser/ui/webui/help/version_updater_ghosium_win.cc'
foreach ($required in @($buildPath, $sourcePath)) {
  if (!(Test-Path $required -PathType Leaf)) {
    throw "Ghosium updater verification is missing required source: $required"
  }
}

$build = [IO.File]::ReadAllText($buildPath)
$source = [IO.File]::ReadAllText($sourcePath)

foreach ($required in @(
  'sources = [ "version_updater_ghosium_win.cc" ]',
  '"//chrome/browser:browser_process"',
  '"//chrome/browser/net"',
  '"//crypto"',
  '"//net"',
  '"//services/network/public/cpp"',
  '"//url"'
)) {
  if (!$build.Contains($required)) {
    throw "Ghosium updater BUILD contract is missing: $required"
  }
}

if ($build -match '(?s)if \(is_win\).*?else \{\s*sources = \[ "version_updater_basic\.cc" \]') {
  throw 'Unbranded Windows builds still select version_updater_basic.cc instead of the Ghosium updater.'
}

foreach ($required in @(
  "kGhosiumCurrentProductVersion[] = `"$productVersion`"",
  'https://updates.ghosium.com/windows/stable.json',
  'url.host_piece() != kGhosiumUpdateHost',
  'CredentialsMode::kOmit',
  'LOAD_BYPASS_CACHE',
  'LOAD_DISABLE_CACHE',
  'schema',
  'Ghosium Browser',
  'windows',
  'stable',
  'available_version.CompareTo(current_version) <= 0',
  'Ghosium-Browser-Setup.exe',
  'expected_size_',
  'crypto::hash::HashFile',
  'base::HexEncode(digest)',
  'base::EqualsCaseInsensitiveASCII(actual_sha256, expected_sha256_)',
  'base::win::IsBinaryTrusted',
  'AppendArgNative(L"/S")',
  'AppendArgNative(L"/UPDATE")',
  'AppendArgNative(L"/DELETESELF")',
  'base::LaunchProcess'
)) {
  if (!$source.Contains($required)) {
    throw "Ghosium updater source contract is missing: $required"
  }
}

foreach ($forbidden in @(
  'BeginUpdateCheck(',
  'google_update_win.h',
  'GoogleUpdate',
  'update.exe',
  'updater.exe',
  'uninstall.exe',
  'powershell.exe',
  'cmd.exe',
  'curl.exe',
  'WINHTTP_ACCESS_TYPE_NO_PROXY'
)) {
  if ($source -match [regex]::Escape($forbidden)) {
    throw "Ghosium updater source contains a forbidden dependency or legacy path: $forbidden"
  }
}

$hashCheck = $source.IndexOf('crypto::hash::HashFile')
$publisherCheck = $source.IndexOf('base::win::IsBinaryTrusted')
$launch = $source.IndexOf('base::LaunchProcess')
if ($hashCheck -lt 0 -or $publisherCheck -lt 0 -or $launch -lt 0 -or
    $hashCheck -gt $launch -or $publisherCheck -gt $launch) {
  throw 'Ghosium updater must verify both SHA-256 and Authenticode publisher before launching Setup.'
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party state during updater verification.'
}
if ($thirdPartyChanges) {
  throw 'Ghosium updater transformation modified third_party sources.'
}

Write-Host 'Ghosium native Windows VersionUpdater contract: OK'
