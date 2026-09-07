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
    # Google/Gemini functionality is not presented as a Ghosium-owned AI
    # product. The public AI Settings entry point is removed below; any shared
    # resource text left in the bundle is neutral instead of falsely branded.
    $body = $body.Replace('AI in Chrome', 'AI features')
    $body = $body.Replace('Gemini in Chromium', 'Gemini')
    $body = $body.Replace('Gemini in Chrome', 'Gemini')
    $body = $body.Replace('You and Google', 'Profile')
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

function Replace-RequiredRegex {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string]$Replacement,
    [Parameter(Mandatory = $true)][string]$AlreadyPresent,
    [Parameter(Mandatory = $true)][string]$Description
  )

  if (!(Test-Path $Path -PathType Leaf)) {
    throw "Pinned source layout changed; $Description target is missing: $Path"
  }

  $text = [IO.File]::ReadAllText($Path)
  if ([regex]::IsMatch($text, $Pattern)) {
    $updated = [regex]::Replace($text, $Pattern, $Replacement, 1)
    [IO.File]::WriteAllText($Path, $updated, [Text.UTF8Encoding]::new($false))
    return
  }

  if (!$text.Contains($AlreadyPresent)) {
    throw "Pinned source layout changed; unable to apply $Description in $Path"
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

# The Google account/sync page is retained internally for compatibility with
# Chromium subsystems, but it is no longer a Ghosium product/navigation section.
Set-GritMessage -Path $settingsStrings -MessageId 'IDS_SETTINGS_PEOPLE' -Value 'Profile'

# Explicitly normalize customize copy even though the Chromium NTP entry points
# are removed below. This prevents a future accidental re-exposure from showing
# upstream product branding.
Set-GritMessage -Path $chromiumStrings -MessageId 'IDS_NTP_CUSTOMIZE_BUTTON_LABEL' -Value 'Customize Ghosium'
Set-GritMessage -Path $chromiumStrings -MessageId 'IDS_SIDE_PANEL_CUSTOMIZE_CHROME_TITLE' -Value 'Customize Ghosium'
Set-GritMessage -Path $chromiumStrings -MessageId 'IDS_NTP_MODULES_SETUP_LIST_TITLE' -Value 'Make Ghosium Yours'
Set-GritMessage -Path $chromiumStrings -MessageId 'IDS_NTP_CUSTOMIZATION_PROMO' -Value 'Customize Ghosium to change its appearance'
Set-GritMessage -Path $chromiumStrings -MessageId 'IDS_IPH_CUSTOMIZE_CHROME_AUTO_OPEN_BODY' -Value 'Customize Ghosium to change its appearance'
Set-GritMessage -Path $chromiumStrings -MessageId 'IDS_IPH_CUSTOMIZE_CHROME_AUTO_OPEN_SCREENREADER' -Value 'Open Customize Ghosium from the New Tab Page to change its appearance'

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

# Remove Google-owned account and Gemini/AI entry points from the Settings menu.
# Their lower-level Chromium code remains untouched where removing it could break
# unrelated browser internals, but Ghosium does not present it as its own feature.
Replace-RequiredRegex `
  -Path $settingsMenuHtml `
  -Pattern '(?s)\s*<a\s+role="menuitem"\s+id="people".*?</a>' `
  -Replacement "`n        <!-- Ghosium: upstream Google account/sync entry intentionally hidden. -->" `
  -AlreadyPresent 'upstream Google account/sync entry intentionally hidden' `
  -Description 'Google account Settings menu removal'
Replace-RequiredRegex `
  -Path $settingsMenuHtml `
  -Pattern '(?s)\s*<a\s+role="menuitem"\s+id="ai".*?</a>' `
  -Replacement "`n        <!-- Ghosium: upstream Google/Gemini AI entry intentionally hidden. -->" `
  -AlreadyPresent 'upstream Google/Gemini AI entry intentionally hidden' `
  -Description 'Google/Gemini AI Settings menu removal'

if (!(Test-Path $settingsMenuTs -PathType Leaf)) {
  throw "Pinned source layout changed; Settings menu TypeScript target is missing: $settingsMenuTs"
}
$settingsMenuTsText = [IO.File]::ReadAllText($settingsMenuTs)
$settingsMenuTsUpdated = $settingsMenuTsText
$settingsMenuTsUpdated = [regex]::Replace($settingsMenuTsUpdated, '(?m)^\s*people:\s*HTMLLinkElement,\r?\n', '')
$settingsMenuTsUpdated = [regex]::Replace($settingsMenuTsUpdated, '(?m)^\s*\[''/people'',\s*''SettingsMenu_PeopleClicked''\],\r?\n', '')
$settingsMenuTsUpdated = [regex]::Replace($settingsMenuTsUpdated, '(?m)^\s*\[''/ai'',\s*''SettingsMenu_AiPageEntryPointClicked''\],\r?\n', '')
if ($settingsMenuTsUpdated -ne $settingsMenuTsText) {
  [IO.File]::WriteAllText($settingsMenuTs, $settingsMenuTsUpdated, [Text.UTF8Encoding]::new($false))
}
$settingsMenuTsText = [IO.File]::ReadAllText($settingsMenuTs)
foreach ($legacyAction in @('SettingsMenu_PeopleClicked', 'SettingsMenu_AiPageEntryPointClicked')) {
  if ($settingsMenuTsText.Contains($legacyAction)) {
    throw "Removed Ghosium Settings entry still has a public menu action: $legacyAction"
  }
}

# A normal Ghosium Settings launch must not land on the hidden Google account
# section. Privacy is a first-party browser setting and is the safe default.
Replace-RequiredRegex `
  -Path $settingsRouteTs `
  -Pattern 'return\s+routes\.PEOPLE;' `
  -Replacement 'return routes.PRIVACY;' `
  -AlreadyPresent 'return routes.PRIVACY;' `
  -Description 'Settings default-route migration away from Google account services'

# Never create the Chromium AI route in Ghosium. A later Glic state update is
# also prevented from re-enabling it after the page has loaded.
Replace-RequiredRegex `
  -Path $settingsUiCc `
  -Pattern '(?s)html_source->AddBoolean\("showAiPage",\s*show_glic_section\s*\|\|\s*show_ai_features_section\s*\|\|\s*enable_ai_mode_search\);' `
  -Replacement 'html_source->AddBoolean("showAiPage", false);' `
  -AlreadyPresent 'html_source->AddBoolean("showAiPage", false);' `
  -Description 'Ghosium AI Settings disablement'
Replace-RequiredRegex `
  -Path $settingsUiCc `
  -Pattern '(?s)if\s*\(show_glic\)\s*\{\s*update\.Set\("showAiPage",\s*true\);\s*\}' `
  -Replacement "if (show_glic) {`n    update.Set(`"showAiPage`", false);`n  }" `
  -AlreadyPresent 'update.Set("showAiPage", false);' `
  -Description 'dynamic Glic AI Settings suppression'

# The user explicitly requested the Chromium NTP customization surface to be
# removed. Strip the visible customize button and its footer context-menu entry
# rather than merely repainting or relabeling them.
Replace-RequiredRegex `
  -Path $ntpAppHtml `
  -Pattern '(?s)\s*\$\{\s*this\.showCustomizeButton_\s*\?\s*html`\s*<ntp-customize-buttons\s+id="customizeButtons".*?</ntp-customize-buttons>\s*`\s*:\s*''''\s*\}' `
  -Replacement "`n      <!-- Ghosium: upstream Chromium NTP customization entry intentionally removed. -->" `
  -AlreadyPresent 'upstream Chromium NTP customization entry intentionally removed' `
  -Description 'Chromium NTP customize-button removal'
Replace-RequiredRegex `
  -Path $ntpFooterContextMenu `
  -Pattern '(?s)\s*AddSeparator\(ui::NORMAL_SEPARATOR\);\s*// Add item: customize chrome\.\s*AddItemWithStringIdAndIcon\(COMMAND_SHOW_CUSTOMIZE_CHROME,.*?kShowCustomizeChromeIdForTesting\);' `
  -Replacement "`n  // Ghosium: upstream Chromium NTP customization context-menu entry removed." `
  -AlreadyPresent 'upstream Chromium NTP customization context-menu entry removed' `
  -Description 'Chromium NTP footer customize-menu removal'

$publicStringFiles = @(
  $chromiumStrings,
  $settingsChromiumStrings,
  $settingsStrings,
  $sharedSettingsStrings,
  $glicStrings
)
$forbiddenVisiblePatterns = @(
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
foreach ($path in $publicStringFiles) {
  $text = [IO.File]::ReadAllText($path)
  $messages = [regex]::Matches($text, '(?s)<message\b[^>]*>(.*?)</message>')
  foreach ($message in $messages) {
    $visible = [System.Net.WebUtility]::HtmlDecode([regex]::Replace($message.Groups[1].Value, '<[^>]+>', ''))
    foreach ($legacyPattern in $forbiddenVisiblePatterns) {
      if ($visible -match $legacyPattern) {
        throw "Legacy public browser branding remains visible in ${path}: $legacyPattern"
      }
    }
  }
}

$settingsText = [IO.File]::ReadAllText($settingsStrings)
$peopleBodies = [regex]::Matches($settingsText, '(?s)<message\s+[^>]*name="IDS_SETTINGS_PEOPLE"[^>]*>(.*?)</message>')
if ($peopleBodies.Count -lt 1 -or @($peopleBodies | Where-Object { $_.Groups[1].Value.Trim() -ne 'Profile' }).Count -gt 0) {
  throw 'Hidden upstream account Settings root was not neutralized to Profile.'
}
$chromiumText = [IO.File]::ReadAllText($chromiumStrings)
foreach ($required in @(
  'Ghosium Browser',
  'Brendigo',
  'Ghosium Browser. All rights reserved.',
  'Customize Ghosium'
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

Write-Host 'Ghosium public surfaces applied: branded product identity; Chromium customization, Google account nav, Gemini/AI and Web Store tile removed.'
