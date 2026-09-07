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
  throw "Public-surface verification requires pinned engine source $expectedRevision; found $actualRevision"
}

function Get-GritMessageBody {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$MessageId
  )

  $text = [IO.File]::ReadAllText($Path)
  $escaped = [regex]::Escape($MessageId)
  $matches = [regex]::Matches($text, '(?s)<message\s+[^>]*name="' + $escaped + '"[^>]*>(.*?)</message>')
  if ($matches.Count -lt 1) {
    throw "Expected GRIT message is missing during Ghosium public-surface verification: $MessageId ($Path)"
  }
  return @($matches | ForEach-Object { $_.Groups[1].Value })
}

function Assert-MessageContains {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$MessageId,
    [Parameter(Mandatory = $true)][string]$Expected
  )

  $bodies = @(Get-GritMessageBody -Path $Path -MessageId $MessageId)
  foreach ($body in $bodies) {
    if (!$body.Contains($Expected)) {
      throw "Ghosium public message $MessageId does not contain expected text '$Expected' in $Path"
    }
  }
}

function Assert-NoForbiddenVisibleBrand {
  param([Parameter(Mandatory = $true)][string]$Path)

  $text = [IO.File]::ReadAllText($Path)
  $messages = [regex]::Matches($text, '(?s)<message\b[^>]*>(.*?)</message>')
  foreach ($message in $messages) {
    $visible = [regex]::Replace($message.Groups[1].Value, '<[^>]+>', '')
    $visible = [System.Net.WebUtility]::HtmlDecode($visible)
    foreach ($forbidden in @(
      'About Chromium',
      'Get help with Chromium',
      'Chromium is your default browser',
      'Make Chromium the default browser',
      'AI in Chrome',
      'Gemini in Chromium',
      'Gemini in Chrome',
      'Chrome Colors',
      'Open Chrome Web Store',
      'You and Google'
    )) {
      if ($visible.Contains($forbidden)) {
        throw "Legacy public browser branding remains visible in ${Path}: $forbidden"
      }
    }
  }
}

$chromiumStrings = Join-Path $sourceRootResolved 'chrome/app/chromium_strings.grd'
$settingsChromiumStrings = Join-Path $sourceRootResolved 'chrome/app/settings_chromium_strings.grdp'
$settingsStrings = Join-Path $sourceRootResolved 'chrome/app/settings_strings.grdp'
$sharedSettingsStrings = Join-Path $sourceRootResolved 'chrome/app/shared_settings_strings.grdp'
$glicStrings = Join-Path $sourceRootResolved 'chrome/app/glic_strings.grdp'
$extensionUiUtil = Join-Path $sourceRootResolved 'chrome/browser/extensions/extension_ui_util.cc'
$productLogoSvg = Join-Path $sourceRootResolved 'chrome/app/theme/chromium/product_logo.svg'
$productLogo32 = Join-Path $sourceRootResolved 'chrome/app/theme/chromium/product_logo_32.png'
$productIcon = Join-Path $sourceRootResolved 'chrome/app/theme/chromium/win/chromium.ico'
$canonicalLogoSvg = Join-Path $repoRoot 'engine/branding/ghosium-mark.svg'

foreach ($path in @(
  $chromiumStrings,
  $settingsChromiumStrings,
  $settingsStrings,
  $sharedSettingsStrings,
  $glicStrings,
  $extensionUiUtil,
  $productLogoSvg,
  $productLogo32,
  $productIcon,
  $canonicalLogoSvg
)) {
  if (!(Test-Path $path -PathType Leaf)) {
    throw "Required Ghosium public-surface file is missing: $path"
  }
}

Assert-MessageContains -Path $chromiumStrings -MessageId 'IDS_PRODUCT_NAME' -Expected 'Ghosium Browser'
Assert-MessageContains -Path $chromiumStrings -MessageId 'IDS_SHORT_PRODUCT_NAME' -Expected 'Ghosium'
Assert-MessageContains -Path $chromiumStrings -MessageId 'IDS_ABOUT_VERSION_COMPANY_NAME' -Expected 'Brendigo'
Assert-MessageContains -Path $chromiumStrings -MessageId 'IDS_ABOUT_VERSION_COPYRIGHT' -Expected 'Brendigo. Ghosium Browser. All rights reserved.'
Assert-MessageContains -Path $settingsChromiumStrings -MessageId 'IDS_SETTINGS_ABOUT_PROGRAM' -Expected 'About Ghosium Browser'
Assert-MessageContains -Path $settingsChromiumStrings -MessageId 'IDS_SETTINGS_GET_HELP_USING_CHROME' -Expected 'Ghosium Support'
Assert-MessageContains -Path $settingsStrings -MessageId 'IDS_SETTINGS_PEOPLE' -Expected 'Ghosium'

foreach ($path in @(
  $chromiumStrings,
  $settingsChromiumStrings,
  $settingsStrings,
  $sharedSettingsStrings,
  $glicStrings
)) {
  Assert-NoForbiddenVisibleBrand -Path $path
}

# Verify the exact public logo consumed by About/Settings is the canonical
# Ghosium mark rather than merely checking that some image exists.
$sourceSvgHash = (Get-FileHash $productLogoSvg -Algorithm SHA256).Hash
$canonicalSvgHash = (Get-FileHash $canonicalLogoSvg -Algorithm SHA256).Hash
if ($sourceSvgHash -ne $canonicalSvgHash) {
  throw 'Chromium product_logo.svg was not replaced by the canonical Ghosium mark.'
}

# PNG and ICO are generated deterministically from the Ghosium mark contract.
# Regenerate expected outputs in an isolated temp tree and compare hashes.
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) "ghosium-public-surface-verify-$PID"
try {
  New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
  $python = Get-Command python -ErrorAction SilentlyContinue
  if (!$python) {
    $python = Get-Command python3 -ErrorAction SilentlyContinue
  }
  if (!$python) {
    throw 'Python 3 is required for deterministic Ghosium public-logo verification.'
  }

  & $python.Source (Join-Path $repoRoot 'scripts/generate-engine-brand-assets.py') $tempRoot
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to generate reference Ghosium public-logo assets.'
  }

  foreach ($pair in @(
    @($productLogo32, (Join-Path $tempRoot 'chrome/app/theme/chromium/product_logo_32.png')),
    @($productIcon, (Join-Path $tempRoot 'chrome/app/theme/chromium/win/chromium.ico'))
  )) {
    $actualHash = (Get-FileHash $pair[0] -Algorithm SHA256).Hash
    $expectedHash = (Get-FileHash $pair[1] -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) {
      throw "Ghosium public-logo binary does not match deterministic canonical output: $($pair[0])"
    }
  }
} finally {
  Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$extensionUiText = [IO.File]::ReadAllText($extensionUiUtil)
$blockPattern = '(?s)if\s*\(app->id\(\)\s*==\s*extensions::kWebStoreAppId\)\s*\{\s*return\s+true;\s*\}'
if ($extensionUiText -notmatch $blockPattern) {
  throw 'Ghosium still allows the upstream Web Store component app onto public New Tab/App Launcher surfaces.'
}
if ($extensionUiText -match 'return\s+app->id\(\)\s*==\s*extensions::kWebStoreAppId\s*&&') {
  throw 'Policy-only upstream Web Store visibility logic returned; Ghosium must hide that component app unconditionally.'
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party source state during public-surface verification.'
}
if ($thirdPartyChanges) {
  throw 'Ghosium public-surface changes touched third_party source.'
}

Write-Host 'Ghosium public surfaces verified: Settings/About branding, canonical logo, and no upstream Web Store tile.'
