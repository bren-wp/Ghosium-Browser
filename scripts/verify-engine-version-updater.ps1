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
  throw "Updater verification requires pinned source $expectedCommit; found $actualCommit"
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
  '#include <algorithm>',
  '#include "base/file_version_info.h"',
  '#include "base/strings/utf_string_conversions.h"',
  "kGhosiumCurrentProductVersion[] = `"$productVersion`"",
  'https://updates.ghosium.com/windows/stable.json',
  'url.host_piece() != kGhosiumUpdateHost',
  'url.EffectiveIntPort() != 443',
  'url.path_piece() != "/windows/Ghosium-Browser-Setup.exe"',
  'CredentialsMode::kOmit',
  'LOAD_BYPASS_CACHE',
  'LOAD_DISABLE_CACHE',
  'SetOnRedirectCallback',
  'OnManifestRedirect',
  'OnSetupRedirect',
  'Ghosium update manifest redirects are not permitted.',
  'Ghosium update package redirects are not permitted.',
  'schema',
  'Ghosium Browser',
  'windows',
  'stable',
  'available_version.CompareTo(current_version) <= 0',
  'base::GetSecureTempDirectory(&secure_temp_dir)',
  'base::CreateTemporaryDirInDir(',
  'FILE_PATH_LITERAL("session-")',
  'Ghosium-Browser-Setup.exe',
  'expected_size_',
  'crypto::hash::HashFile',
  'base::HexEncode(digest)',
  'base::EqualsCaseInsensitiveASCII(actual_sha256, expected_sha256_)',
  'base::win::IsBinaryTrusted',
  'true /* force_verify_in_dev_builds */',
  'FileVersionInfo::CreateFileVersionInfo(setup_path_)',
  'setup_product_name != "Ghosium Browser"',
  'setup_company_name != "Brendigo"',
  'setup_product_version != available_version_',
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
  'WINHTTP_ACCESS_TYPE_NO_PROXY',
  'false /* force_verify_in_dev_builds */',
  'base::EndsWith(url.path_piece(), "/Ghosium-Browser-Setup.exe"',
  'base::GetTempDir(&temp_dir)',
  'update_dir_ = temp_dir.Append(FILE_PATH_LITERAL("Brendigo"))'
)) {
  if ($source -match [regex]::Escape($forbidden)) {
    throw "Ghosium updater source contains a forbidden dependency or legacy/loose trust path: $forbidden"
  }
}

$manifestRedirectHook = $source.IndexOf('manifest_loader_->SetOnRedirectCallback')
$manifestDownload = $source.IndexOf('manifest_loader_->DownloadToString')
$setupRedirectHook = $source.IndexOf('setup_loader_->SetOnRedirectCallback')
$setupDownload = $source.IndexOf('setup_loader_->DownloadToFile')
if ($manifestRedirectHook -lt 0 -or $manifestDownload -lt 0 -or
    $setupRedirectHook -lt 0 -or $setupDownload -lt 0 -or
    $manifestRedirectHook -gt $manifestDownload -or $setupRedirectHook -gt $setupDownload) {
  throw 'Ghosium updater must install redirect rejection before starting manifest and Setup downloads.'
}

$secureTemp = $source.IndexOf('base::GetSecureTempDirectory(&secure_temp_dir)')
$sessionDir = $source.IndexOf('base::CreateTemporaryDirInDir(')
$hashCheck = $source.IndexOf('crypto::hash::HashFile')
$publisherCheck = $source.IndexOf('base::win::IsBinaryTrusted')
$identityCheck = $source.IndexOf('FileVersionInfo::CreateFileVersionInfo(setup_path_)')
$versionBinding = $source.IndexOf('setup_product_version != available_version_')
$launch = $source.IndexOf('base::LaunchProcess')
if ($secureTemp -lt 0 -or $sessionDir -lt 0 -or $setupDownload -lt 0 -or
    $hashCheck -lt 0 -or $publisherCheck -lt 0 -or $identityCheck -lt 0 -or
    $versionBinding -lt 0 -or $launch -lt 0 -or
    $secureTemp -gt $sessionDir -or $sessionDir -gt $setupDownload -or
    $setupDownload -gt $hashCheck -or $hashCheck -gt $publisherCheck -or
    $publisherCheck -gt $identityCheck -or $identityCheck -gt $versionBinding -or
    $versionBinding -gt $launch) {
  throw 'Ghosium updater must isolate secure staging before download, then verify SHA-256, Authenticode publisher and signed Setup identity/version before launch.'
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party state during updater verification.'
}
if ($thirdPartyChanges) {
  throw 'Ghosium updater transformation modified third_party sources.'
}

Write-Host 'Ghosium native Windows VersionUpdater: exact host/path/port, no redirects, isolated secure staging, SHA-256, Authenticode and signed PE anti-rollback binding: OK'
