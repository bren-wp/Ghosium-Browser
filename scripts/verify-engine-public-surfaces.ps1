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
  $forbiddenPatterns = @(
    'About Chromium(?!OS)',
    'Get help with Chromium\b',
    'Chromium is your default browser',
    'Make Chromium the default browser',
    'AI in Chrome',
    'Gemini in Chromium',
    'Gemini in Chrome',
    'Chrome Colors',
    'Open Chrome Web Store',
    'You and Google',
    'Customize Chromium',
    'Personalize Chromium',
    'Make Chromium Yours'
  )

  foreach ($message in $messages) {
    $visible = [regex]::Replace($message.Groups[1].Value, '<[^>]+>', '')
    $visible = [System.Net.WebUtility]::HtmlDecode($visible)
    foreach ($pattern in $forbiddenPatterns) {
      if ($visible -match $pattern) {
        throw "Legacy public browser branding remains visible in ${Path}: $pattern"
      }
    }
  }
}

function Assert-FileContains {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Expected,
    [Parameter(Mandatory = $true)][string]$Description
  )

  if (![IO.File]::ReadAllText($Path).Contains($Expected)) {
    throw "$Description is missing from $Path"
  }
}

function Assert-FileNotContains {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Forbidden,
    [Parameter(Mandatory = $true)][string]$Description
  )

  if ([IO.File]::ReadAllText($Path).Contains($Forbidden)) {
    throw "$Description remains in $Path"
  }
}

$chromiumStrings = Join-Path $sourceRootResolved 'chrome/app/chromium_strings.grd'
$settingsChromiumStrings = Join-Path $sourceRootResolved 'chrome/app/settings_chromium_strings.grdp'
$settingsStrings = Join-Path $sourceRootResolved 'chrome/app/settings_strings.grdp'
$sharedSettingsStrings = Join-Path $sourceRootResolved 'chrome/app/shared_settings_strings.grdp'
$glicStrings = Join-Path $sourceRootResolved 'chrome/app/glic_strings.grdp'
$extensionUiUtil = Join-Path $sourceRootResolved 'chrome/browser/extensions/extension_ui_util.cc'
$settingsMenuHtml = Join-Path $sourceRootResolved 'chrome/browser/resources/settings/settings_menu/settings_menu.html'
$settingsMenuTs = Join-Path $sourceRootResolved 'chrome/browser/resources/settings/settings_menu/settings_menu.ts'
$settingsRouteTs = Join-Path $sourceRootResolved 'chrome/browser/resources/settings/route.ts'
$settingsUiCc = Join-Path $sourceRootResolved 'chrome/browser/ui/webui/settings/settings_ui.cc'
$ntpAppHtml = Join-Path $sourceRootResolved 'chrome/browser/resources/new_tab_page/app.html'
$ntpFooterContextMenu = Join-Path $sourceRootResolved 'chrome/browser/ui/webui/new_tab_footer/footer_context_menu.cc'
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
  $settingsMenuHtml,
  $settingsMenuTs,
  $settingsRouteTs,
  $settingsUiCc,
  $ntpAppHtml,
  $ntpFooterContextMenu,
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
Assert-MessageContains -Path $settingsStrings -MessageId 'IDS_SETTINGS_PEOPLE' -Expected 'Profile'
Assert-MessageContains -Path $chromiumStrings -MessageId 'IDS_NTP_CUSTOMIZE_BUTTON_LABEL' -Expected 'Customize Ghosium'
Assert-MessageContains -Path $chromiumStrings -MessageId 'IDS_SIDE_PANEL_CUSTOMIZE_CHROME_TITLE' -Expected 'Customize Ghosium'
Assert-MessageContains -Path $chromiumStrings -MessageId 'IDS_NTP_MODULES_SETUP_LIST_TITLE' -Expected 'Make Ghosium Yours'

foreach ($path in @(
  $chromiumStrings,
  $settingsChromiumStrings,
  $settingsStrings,
  $sharedSettingsStrings,
  $glicStrings
)) {
  Assert-NoForbiddenVisibleBrand -Path $path
}

# Google account/sync and Gemini/AI are not Ghosium-owned product sections.
# They must not be first-class Settings navigation or the Settings landing page.
Assert-FileNotContains -Path $settingsMenuHtml -Forbidden 'id="people"' -Description 'Google account Settings menu entry'
Assert-FileNotContains -Path $settingsMenuHtml -Forbidden 'id="ai"' -Description 'Google/Gemini AI Settings menu entry'
Assert-FileContains -Path $settingsMenuHtml -Expected 'upstream Google account/sync entry intentionally hidden' -Description 'Ghosium account-menu suppression marker'
Assert-FileContains -Path $settingsMenuHtml -Expected 'upstream Google/Gemini AI entry intentionally hidden' -Description 'Ghosium AI-menu suppression marker'
Assert-FileNotContains -Path $settingsMenuTs -Forbidden 'SettingsMenu_PeopleClicked' -Description 'Google account Settings public menu action'
Assert-FileNotContains -Path $settingsMenuTs -Forbidden 'SettingsMenu_AiPageEntryPointClicked' -Description 'Google/Gemini AI Settings public menu action'
Assert-FileNotContains -Path $settingsRouteTs -Forbidden 'return routes.PEOPLE;' -Description 'Google account default Settings route'
Assert-FileContains -Path $settingsRouteTs -Expected 'return routes.PRIVACY;' -Description 'Ghosium privacy-first Settings landing route'
Assert-FileContains -Path $settingsUiCc -Expected 'html_source->AddBoolean("showAiPage", false);' -Description 'Ghosium AI Settings backend disablement'
Assert-FileNotContains -Path $settingsUiCc -Forbidden 'update.Set("showAiPage", true);' -Description 'dynamic Google/Gemini AI Settings re-enablement'

# The Chromium New Tab customization UI was explicitly requested to be removed,
# not simply relabeled. Both visible entry points are therefore forbidden.
Assert-FileNotContains -Path $ntpAppHtml -Forbidden '<ntp-customize-buttons id="customizeButtons"' -Description 'Chromium New Tab customize button'
Assert-FileContains -Path $ntpAppHtml -Expected 'upstream Chromium NTP customization entry intentionally removed' -Description 'Ghosium NTP customize-button suppression marker'
Assert-FileNotContains -Path $ntpFooterContextMenu -Forbidden 'AddItemWithStringIdAndIcon(COMMAND_SHOW_CUSTOMIZE_CHROME' -Description 'Chromium New Tab footer customize action'
Assert-FileContains -Path $ntpFooterContextMenu -Expected 'upstream Chromium NTP customization context-menu entry removed' -Description 'Ghosium NTP footer customize suppression marker'

$sourceSvgHash = (Get-FileHash $productLogoSvg -Algorithm SHA256).Hash
$canonicalSvgHash = (Get-FileHash $canonicalLogoSvg -Algorithm SHA256).Hash
if ($sourceSvgHash -ne $canonicalSvgHash) {
  throw 'Chromium product_logo.svg was not replaced by the canonical Ghosium mark.'
}

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

Write-Host 'Ghosium public surfaces verified: Ghosium identity retained; Chromium customization, Google account nav, Gemini/AI and Web Store tile are not public.'
