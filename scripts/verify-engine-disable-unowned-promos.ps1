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
  throw "Promo verification requires pinned source $expectedRevision; found $actualRevision"
}

$promoFeatures = Join-Path $sourceRootResolved 'components/desktop_to_mobile_promos/features.cc'
if (!(Test-Path $promoFeatures -PathType Leaf)) {
  throw "Required desktop-to-mobile promo source is missing: $promoFeatures"
}
$text = [IO.File]::ReadAllText($promoFeatures)

foreach ($functionName in @(
  'MobilePromoOnDesktopEnabled',
  'IsMobilePromoOnDesktopRecordActiveDaysEnabled',
  'IsMobilePromoOnDesktopNotificationsEnabled',
  'IsMobileNTPPromoOnDesktopEnabled'
)) {
  $escaped = [regex]::Escape($functionName)
  $pattern = 'bool\s+' + $escaped + '\s*\(\s*\)\s*\{\s*return\s+false;\s*\}'
  if ($text -notmatch $pattern) {
    throw "Ghosium can still enable an unowned desktop-to-mobile promotion path: $functionName"
  }
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party state during unowned-promo audit.'
}
if ($thirdPartyChanges) {
  throw 'Unowned-promo audit detected third_party modifications.'
}

Write-Host 'Ghosium unowned-promo audit: mobile acquisition, notifications, NTP mobile promo and active-day tracking are disabled.'
