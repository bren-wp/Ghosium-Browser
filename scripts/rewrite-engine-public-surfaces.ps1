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
  throw "Refusing to rewrite Ghosium public surfaces on an unpinned checkout. Expected $expectedRevision; found $actualRevision"
}

function Rewrite-GritMessageBodies {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (!(Test-Path $Path -PathType Leaf)) {
    throw "Pinned source layout changed; public-branding string file is missing: $Path"
  }

  $text = [IO.File]::ReadAllText($Path)
  $pattern = '(?s)(<message\b[^>]*>)(.*?)(</message>)'
  $updated = [regex]::Replace($text, $pattern, {
    param($match)
    $body = $match.Groups[2].Value

    $body = $body.Replace('Chrome Web Store', 'Ghosium Store')
    $body = $body.Replace('Chrome Colors', 'Ghosium Colors')
    $body = $body.Replace('AI in Chrome', 'AI in Ghosium')
    $body = $body.Replace('Gemini in Chromium', 'Gemini in Ghosium')
    $body = $body.Replace('Gemini in Chrome', 'Gemini in Ghosium')
    $body = $body.Replace('You and Google', 'Ghosium')
    $body = $body.Replace('Google Chrome for Testing', 'Ghosium Browser')
    $body = $body.Replace('Chrome for Testing', 'Ghosium Browser')
    $body = $body.Replace('Google Chrome', 'Ghosium Browser')
    $body = [regex]::Replace($body, '\bChromium\b', 'Ghosium Browser')
    $body = [regex]::Replace($body, '\bChrome\b', 'Ghosium Browser')
    $body = $body.Replace('Ghosium Browser browser', 'Ghosium Browser')
    $body = $body.Replace('Ghosium Browser Browser', 'Ghosium Browser')

    return $match.Groups[1].Value + $body + $match.Groups[3].Value
  })

  if ($updated -ne $text) {
    [IO.File]::WriteAllText($Path, $updated, [Text.UTF8Encoding]::new($false))
    Write-Host "Completed Ghosium public-string branding: $Path"
  }
}

function Set-GritMessage {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$MessageId,
    [Parameter(Mandatory = $true)][string]$Value
  )

  $text = [IO.File]::ReadAllText($Path)
  $escapedId = [regex]::Escape($MessageId)
  $pattern = '(?s)(<message\s+[^>]*name="' + $escapedId + '"[^>]*>)(.*?)(</message>)'
  $matches = [regex]::Matches($text, $pattern)
  if ($matches.Count -lt 1) {
    throw "Expected public Ghosium GRIT message was not found: $MessageId in $Path"
  }

  $updated = [regex]::Replace(
    $text,
    $pattern,
    { param($match) $match.Groups[1].Value + "`n      " + $Value + "`n    " + $match.Groups[3].Value }
  )
  [IO.File]::WriteAllText($Path, $updated, [Text.UTF8Encoding]::new($false))
}

$chromiumStrings = Join-Path $sourceRootResolved 'chrome/app/chromium_strings.grd'
$settingsChromiumStrings = Join-Path $sourceRootResolved 'chrome/app/settings_chromium_strings.grdp'
$settingsStrings = Join-Path $sourceRootResolved 'chrome/app/settings_strings.grdp'
$sharedSettingsStrings = Join-Path $sourceRootResolved 'chrome/app/shared_settings_strings.grdp'
$glicStrings = Join-Path $sourceRootResolved 'chrome/app/glic_strings.grdp'
$extensionUiUtil = Join-Path $sourceRootResolved 'chrome/browser/extensions/extension_ui_util.cc'

foreach ($path in @(
  $chromiumStrings,
  $settingsChromiumStrings,
  $settingsStrings,
  $sharedSettingsStrings,
  $glicStrings
)) {
  Rewrite-GritMessageBodies -Path $path
}

Set-GritMessage -Path $chromiumStrings -MessageId 'IDS_PRODUCT_NAME' -Value 'Ghosium Browser'
Set-GritMessage -Path $chromiumStrings -MessageId 'IDS_SHORT_PRODUCT_NAME' -Value 'Ghosium'
Set-GritMessage -Path $chromiumStrings -MessageId 'IDS_ABOUT_VERSION_COMPANY_NAME' -Value 'Brendigo'
Set-GritMessage `
  -Path $chromiumStrings `
  -MessageId 'IDS_ABOUT_VERSION_COPYRIGHT' `
  -Value 'Copyright <ph name="YEAR">{0,date,y}<ex>2026</ex></ph> Brendigo. Ghosium Browser. All rights reserved.'
Set-GritMessage -Path $settingsChromiumStrings -MessageId 'IDS_SETTINGS_ABOUT_PROGRAM' -Value 'About Ghosium Browser'
Set-GritMessage -Path $settingsChromiumStrings -MessageId 'IDS_SETTINGS_GET_HELP_USING_CHROME' -Value 'Ghosium Support'
Set-GritMessage -Path $settingsStrings -MessageId 'IDS_SETTINGS_PEOPLE' -Value 'Ghosium'

if (!(Test-Path $extensionUiUtil -PathType Leaf)) {
  throw "Pinned source layout changed; extension UI target is missing: $extensionUiUtil"
}
$extensionUiText = [IO.File]::ReadAllText($extensionUiUtil)
$webStorePattern = '(?s)return\s+app->id\(\)\s*==\s*extensions::kWebStoreAppId\s*&&\s*profile->GetPrefs\(\)->GetBoolean\(\s*policy::policy_prefs::kHideWebStoreIcon\s*\);'
$webStoreReplacement = @'
if (app->id() == extensions::kWebStoreAppId) {
    return true;
  }

  return false;
'@.TrimEnd("`r", "`n")
if ([regex]::IsMatch($extensionUiText, $webStorePattern)) {
  $extensionUiText = [regex]::Replace($extensionUiText, $webStorePattern, $webStoreReplacement, 1)
  [IO.File]::WriteAllText($extensionUiUtil, $extensionUiText, [Text.UTF8Encoding]::new($false))
} elseif (!$extensionUiText.Contains('if (app->id() == extensions::kWebStoreAppId) {') -or
          !$extensionUiText.Contains('return true;')) {
  throw 'Unable to hide the upstream Web Store app; extension_ui_util.cc layout changed.'
}

$publicStringFiles = @(
  $chromiumStrings,
  $settingsChromiumStrings,
  $settingsStrings,
  $sharedSettingsStrings,
  $glicStrings
)
$forbiddenVisible = @(
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
)
foreach ($path in $publicStringFiles) {
  $text = [IO.File]::ReadAllText($path)
  $messages = [regex]::Matches($text, '(?s)<message\b[^>]*>(.*?)</message>')
  foreach ($message in $messages) {
    $visible = [System.Net.WebUtility]::HtmlDecode([regex]::Replace($message.Groups[1].Value, '<[^>]+>', ''))
    foreach ($legacy in $forbiddenVisible) {
      if ($visible.Contains($legacy)) {
        throw "Legacy public browser branding remains visible in ${path}: $legacy"
      }
    }
  }
}

$settingsText = [IO.File]::ReadAllText($settingsStrings)
$peopleBodies = [regex]::Matches($settingsText, '(?s)<message\s+[^>]*name="IDS_SETTINGS_PEOPLE"[^>]*>(.*?)</message>')
if ($peopleBodies.Count -lt 1 -or @($peopleBodies | Where-Object { !$_.Groups[1].Value.Contains('Ghosium') }).Count -gt 0) {
  throw 'Ghosium Settings top-level branded section was not installed.'
}
$chromiumText = [IO.File]::ReadAllText($chromiumStrings)
foreach ($required in @(
  'Ghosium Browser',
  'Brendigo',
  'Ghosium Browser. All rights reserved.'
)) {
  if (!$chromiumText.Contains($required)) {
    throw "Ghosium About/product identity is missing: $required"
  }
}
$settingsChromiumText = [IO.File]::ReadAllText($settingsChromiumStrings)
foreach ($required in @('About Ghosium Browser', 'Ghosium Support')) {
  if (!$settingsChromiumText.Contains($required)) {
    throw "Ghosium Settings/About identity is missing: $required"
  }
}
$extensionUiText = [IO.File]::ReadAllText($extensionUiUtil)
if (!$extensionUiText.Contains('app->id() == extensions::kWebStoreAppId') -or
    !$extensionUiText.Contains('return true;')) {
  throw 'Upstream Web Store component app is not blocked from Ghosium public launch surfaces.'
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party source state after public-surface branding.'
}
if ($thirdPartyChanges) {
  throw 'Public-surface branding modified third_party sources; refusing to continue.'
}

Write-Host 'Ghosium Settings/About/New Tab public surface branding applied.'
