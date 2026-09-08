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
  throw "Refusing to rewrite product version in an unpinned checkout. Expected $expectedCommit; found $actualCommit"
}
if ($productVersion -notmatch '^0\.[1-9]\d*\.\d+$') {
  throw "Ghosium product VERSION must use the 0.x.y line; found '$productVersion'."
}

$versionUi = Join-Path $sourceRootResolved 'chrome/browser/ui/webui/version/version_ui.cc'
$header = Join-Path $sourceRootResolved 'chrome/common/ghosium_product_version.h'
if (!(Test-Path $versionUi -PathType Leaf)) {
  throw "Pinned source layout changed; version UI source is missing: $versionUi"
}

function Replace-RequiredLiteral {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [Parameter(Mandatory = $true)][string]$OldValue,
    [Parameter(Mandatory = $true)][string]$NewValue,
    [Parameter(Mandatory = $true)][string]$Description
  )

  if ($Text.Contains($NewValue)) {
    return $Text
  }
  if (!$Text.Contains($OldValue)) {
    throw "Pinned source changed; unable to apply Ghosium product version at $Description."
  }
  return $Text.Replace($OldValue, $NewValue)
}

$headerText = @"
// Copyright 2026 Brendigo
// Ghosium product version generated from the repository VERSION contract.
// The browser-engine compatibility version remains independent.

#ifndef CHROME_COMMON_GHOSIUM_PRODUCT_VERSION_H_
#define CHROME_COMMON_GHOSIUM_PRODUCT_VERSION_H_

namespace ghosium {
inline constexpr char kProductVersion[] = "$productVersion";
}  // namespace ghosium

#endif  // CHROME_COMMON_GHOSIUM_PRODUCT_VERSION_H_
"@
[IO.File]::WriteAllText($header, $headerText, [Text.UTF8Encoding]::new($false))

$text = [IO.File]::ReadAllText($versionUi)
$updated = $text
$updated = Replace-RequiredLiteral `
  -Text $updated `
  -OldValue '#include "chrome/common/url_constants.h"' `
  -NewValue "#include `"chrome/common/url_constants.h`"`n#include `"chrome/common/ghosium_product_version.h`"" `
  -Description 'version_ui.cc include list'

$updated = Replace-RequiredLiteral `
  -Text $updated `
  -OldValue "html_source->AddString(version_ui::kVersion,`n                         version_info::GetVersionNumber());" `
  -NewValue "html_source->AddString(version_ui::kVersion,`n                         ghosium::kProductVersion);" `
  -Description 'ghost://version product version value'

$updated = Replace-RequiredLiteral `
  -Text $updated `
  -OldValue 'base::UTF8ToUTF16(version_info::GetVersionNumber()),' `
  -NewValue 'base::UTF8ToUTF16(ghosium::kProductVersion),' `
  -Description 'Settings About annotated version'

if ($updated -ne $text) {
  [IO.File]::WriteAllText($versionUi, $updated, [Text.UTF8Encoding]::new($false))
}

$verify = [IO.File]::ReadAllText($versionUi)
foreach ($required in @(
  '#include "chrome/common/ghosium_product_version.h"',
  'ghosium::kProductVersion',
  'base::UTF8ToUTF16(ghosium::kProductVersion)'
)) {
  if (!$verify.Contains($required)) {
    throw "Ghosium product version source verification failed: missing $required"
  }
}

$verifyHeader = [IO.File]::ReadAllText($header)
if (!$verifyHeader.Contains("kProductVersion[] = `"$productVersion`"")) {
  throw 'Generated Ghosium product version header does not match repository VERSION.'
}

# The Windows About-page updater uses the same product VERSION contract. Keep
# the updater source generation coupled to this version transform so a version
# bump cannot produce a browser that checks updates using stale product data.
& (Join-Path $PSScriptRoot 'rewrite-engine-version-updater.ps1') -SourceRoot $sourceRootResolved
if ($LASTEXITCODE -ne 0) {
  throw 'Ghosium native Windows VersionUpdater integration failed.'
}

# Chromium's generic trust helper intentionally bypasses Authenticode for
# unbranded builds unless verification is forced. Ghosium is an unbranded
# Chromium fork, so force signature + publisher verification before the update
# Setup can ever be launched.
& (Join-Path $PSScriptRoot 'harden-engine-version-updater.ps1') -SourceRoot $sourceRootResolved
if ($LASTEXITCODE -ne 0) {
  throw 'Ghosium native Windows VersionUpdater hardening failed.'
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party source state after product-version rewrite.'
}
if ($thirdPartyChanges) {
  throw 'Product-version rewrite modified third_party sources; refusing to continue.'
}

Write-Host "Ghosium product version $productVersion applied to About surfaces and hardened native updater; engine compatibility version remains separate."
