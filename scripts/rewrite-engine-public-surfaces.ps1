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

    # Prefer natural Ghosium UI copy for common public labels before applying
    # generic browser-brand substitutions.
    $body = $body.Replace('Chrome Web Store', 'Ghosium Store')
    $body = $body.Replace('Chrome Colors', 'Ghosium Colors')
    $body = $body.Replace('AI in Chrome', 'AI in Ghosium')
    $body = $body.Replace('Gemini in Chromium', 'Gemini in Ghosium')
    $body = $body.Replace('Gemini in Chrome', 'Gemini in Ghosium')
    $body = $body.Replace('You and Google', 'Profile and services')
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

# About must identify the distributed product and publisher first. Chromium and
# other upstream copyright/license notices remain preserved in the dedicated
# third-party/legal material and the About license paragraph.
Set-GritMessage `
  -Path $chromiumStrings `
  -MessageId 'IDS_ABOUT_VERSION_COMPANY_NAME' `
  -Value 'Brendigo'
Set-GritMessage `
  -Path $chromiumStrings `
  -MessageId 'IDS_ABOUT_VERSION_COPYRIGHT' `
  -Value 'Copyright <ph name="YEAR">{0,date,y}<ex>2026</ex></ph> Brendigo. Ghosium Browser. All rights reserved.'

# The generic Settings source owns the top-level account/services navigation.
# Do not present it as a Google-owned browser section in Ghosium.
Set-GritMessage `
  -Path $settingsStrings `
  -MessageId 'IDS_SETTINGS_PEOPLE' `
  -Value 'Profile and services'

# The upstream Web Store component application must never appear as a Ghosium
# New Tab/App Launcher tile. Ghosium Store remains reachable through the
# separately rewritten first-party Store links at https://store.ghosium.com/.
if (!(Test-Path $extensionUiUtil -PathType Leaf)) {
  throw "Pinned source layout changed; extension UI target is missing: $extensionUiUtil"
}
$extensionUiText = [IO.File]::ReadAllText($extensionUiUtil)
$oldBlock = @'
bool IsBlockedByPolicy(const Extension* app, content::BrowserContext* context) {
  Profile* profile = Profile::FromBrowserContext(context);
  DCHECK(profile);

  return app->id() == extensions::kWebStoreAppId &&
         profile->GetPrefs()->GetBoolean(
             policy::policy_prefs::kHideWebStoreIcon);
}
'@
$newBlock = @'
bool IsBlockedByPolicy(const Extension* app, content::BrowserContext* context) {
  Profile* profile = Profile::FromBrowserContext(context);
  DCHECK(profile);

  // Ghosium has its own Store surface. Never expose the upstream Web Store
  // component app as a New Tab/App Launcher tile in the distributed browser.
  if (app->id() == extensions::kWebStoreAppId) {
    return true;
  }

  return false;
}
'@
if ($extensionUiText.Contains($oldBlock)) {
  $extensionUiText = $extensionUiText.Replace($oldBlock, $newBlock)
  [IO.File]::WriteAllText($extensionUiUtil, $extensionUiText, [Text.UTF8Encoding]::new($false))
} elseif (!$extensionUiText.Contains('if (app->id() == extensions::kWebStoreAppId) {') -or
          !$extensionUiText.Contains('return true;')) {
  throw 'Unable to hide the upstream Web Store app; extension_ui_util.cc layout changed.'
}

# Fail closed on the exact regressions visible in the reported Settings/New Tab
# screenshots. Generic Google service names may remain where they accurately
# describe a distinct service, but the browser itself must never be presented as
# Chromium/Chrome or expose the old Web Store tile.
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
  'Open Chrome Web Store'
)
foreach ($path in $publicStringFiles) {
  $text = [IO.File]::ReadAllText($path)
  foreach ($legacy in $forbiddenVisible) {
    if ($text.Contains($legacy)) {
      throw "Legacy public browser branding remains in $path: $legacy"
    }
  }
}

$settingsText = [IO.File]::ReadAllText($settingsStrings)
if (!$settingsText.Contains('Profile and services')) {
  throw 'Ghosium Settings top-level profile/services label was not installed.'
}
$chromiumText = [IO.File]::ReadAllText($chromiumStrings)
foreach ($required in @(
  'Brendigo',
  'Ghosium Browser. All rights reserved.'
)) {
  if (!$chromiumText.Contains($required)) {
    throw "Ghosium About publisher identity is missing: $required"
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
