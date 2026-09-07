param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedRevision = (Get-Content (Join-Path $repoRoot 'ENGINE_SOURCE_REVISION') -Raw).Trim()
$sourceRootResolved = (Resolve-Path $SourceRoot).Path

$actualRevision = (& git -C $sourceRootResolved rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualRevision -ne $expectedRevision) {
  throw "Refusing to disable upstream promos on an unpinned checkout. Expected $expectedRevision; found $actualRevision"
}

$promoFeatures = Join-Path $sourceRootResolved 'components/desktop_to_mobile_promos/features.cc'
if (!(Test-Path $promoFeatures -PathType Leaf)) {
  throw "Pinned source layout changed; desktop-to-mobile promo features are missing: $promoFeatures"
}

function Force-BoolFunctionFalse {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$FunctionName
  )

  $text = [IO.File]::ReadAllText($Path)
  $escaped = [regex]::Escape($FunctionName)
  $already = 'bool\s+' + $escaped + '\s*\(\s*\)\s*\{\s*return\s+false;\s*\}'
  if ($text -match $already) {
    return
  }

  $pattern = '(?s)bool\s+' + $escaped + '\s*\(\s*\)\s*\{.*?\n\}'
  if ($text -notmatch $pattern) {
    throw "Pinned Chromium promo layout changed; function not found: $FunctionName"
  }

  $replacement = "bool $FunctionName() {`n  return false;`n}"
  $updated = [regex]::Replace($text, $pattern, $replacement, 1)
  [IO.File]::WriteAllText($Path, $updated, [Text.UTF8Encoding]::new($false))
  Write-Host "Disabled unowned Chromium promo function: $FunctionName"
}

# Ghosium does not currently ship a Ghosium mobile browser. Do not repurpose
# Chrome/Chromium iOS/Android acquisition campaigns under the Ghosium brand.
Force-BoolFunctionFalse -Path $promoFeatures -FunctionName 'MobilePromoOnDesktopEnabled'
Force-BoolFunctionFalse -Path $promoFeatures -FunctionName 'IsMobilePromoOnDesktopRecordActiveDaysEnabled'
Force-BoolFunctionFalse -Path $promoFeatures -FunctionName 'IsMobilePromoOnDesktopNotificationsEnabled'
Force-BoolFunctionFalse -Path $promoFeatures -FunctionName 'IsMobileNTPPromoOnDesktopEnabled'

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party state after unowned promo suppression.'
}
if ($thirdPartyChanges) {
  throw 'Unowned promo suppression modified third_party source.'
}

Write-Host 'Ghosium unowned-promo policy applied: desktop-to-mobile and NTP mobile promotions are disabled.'
