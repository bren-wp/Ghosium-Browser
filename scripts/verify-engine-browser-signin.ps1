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
  throw "Browser sign-in verification requires pinned source $expectedRevision; found $actualRevision"
}

$accountConsistency = Join-Path $sourceRootResolved 'chrome/browser/signin/account_consistency_mode_manager.cc'
$personalizationHtml = Join-Path $sourceRootResolved 'chrome/browser/resources/settings/privacy_page/personalization_options.html'
$introUi = Join-Path $sourceRootResolved 'chrome/browser/ui/webui/intro/intro_ui.cc'
$introHtml = Join-Path $sourceRootResolved 'chrome/browser/resources/intro/sign_in_promo.html.ts'
$introTs = Join-Path $sourceRootResolved 'chrome/browser/resources/intro/sign_in_promo.ts'
$introRefreshHtml = Join-Path $sourceRootResolved 'chrome/browser/resources/intro/sign_in_promo_refresh.html.ts'
$introRefreshTs = Join-Path $sourceRootResolved 'chrome/browser/resources/intro/sign_in_promo_refresh.ts'

foreach ($path in @(
  $accountConsistency,
  $personalizationHtml,
  $introUi,
  $introHtml,
  $introTs,
  $introRefreshHtml,
  $introRefreshTs
)) {
  if (!(Test-Path $path -PathType Leaf)) {
    throw "Required Ghosium browser-account contract source is missing: $path"
  }
}

$accountText = [IO.File]::ReadAllText($accountConsistency)
if ($accountText -notmatch '(?s)bool IsBrowserSigninAllowedByCommandLine\(\) \{\s*// Ghosium intentionally does not expose Google/GAIA browser sign-in\.\s*return false;\s*\}') {
  throw 'Google/GAIA browser sign-in can still be enabled by the Chromium account-consistency layer.'
}
if (!$accountText.Contains('registry->RegisterBooleanPref(prefs::kSigninAllowedOnNextStartup, false);')) {
  throw 'Browser sign-in still defaults to enabled for new Ghosium profiles.'
}
if ($accountText.Contains('registry->RegisterBooleanPref(prefs::kSigninAllowedOnNextStartup, true);')) {
  throw 'Legacy browser sign-in preference default returned.'
}

$personalizationText = [IO.File]::ReadAllText($personalizationHtml)
if ($personalizationText -notmatch '(?s)<div id="chromeSigninUserChoiceSetting".*?\bhidden\b') {
  throw 'Chrome sign-in user-choice control is not statically hidden in Ghosium Settings.'
}
if ($personalizationText -notmatch '(?s)<settings-toggle-button id="signinAllowedToggle".*?\bhidden\b') {
  throw 'Browser sign-in toggle is not statically hidden in Ghosium Settings.'
}
if ($personalizationText.Contains('?hidden="${!this.chromeSigninUserChoiceInfo_?.shouldShowSettings}"') -or
    $personalizationText.Contains('?hidden="${!this.signinAvailable_}"')) {
  throw 'A runtime condition can still expose a browser-account control in Ghosium Settings.'
}

$introUiText = [IO.File]::ReadAllText($introUi)
if (!$introUiText.Contains('const int title_id = IDS_FRE_WELCOME_TITLE;')) {
  throw 'First-run still uses a browser-account sign-in title instead of the Ghosium welcome title.'
}
if (!$introUiText.Contains('{"pageSubtitle", IDS_PRODUCT_DESCRIPTION},')) {
  throw 'First-run still presents a Google account/sync-oriented subtitle.'
}
if (!$introUiText.Contains('IDS_FRE_WELCOME_START_BUTTON_LABEL);')) {
  throw 'First-run continue-without-account path is not presented as the normal Start browsing action.'
}

foreach ($path in @($introHtml, $introRefreshHtml)) {
  $text = [IO.File]::ReadAllText($path)
  if ($text.Contains('id="acceptSignInButton"')) {
    throw "Google/GAIA account CTA remains visible in Ghosium first-run UI: $path"
  }
  if (!$text.Contains('Google/GAIA browser sign-in CTA intentionally removed')) {
    throw "Ghosium first-run account-removal marker is missing: $path"
  }
  if (!$text.Contains('id="declineSignInButton"')) {
    throw "Account-free first-run continuation button is missing: $path"
  }
}

$introTsText = [IO.File]::ReadAllText($introTs)
$introRefreshTsText = [IO.File]::ReadAllText($introRefreshTs)
if (!$introTsText.Contains('this.benefitCards_ = [];')) {
  throw 'Legacy first-run still renders Google account/sync benefit cards.'
}
if (!$introRefreshTsText.Contains('this.benefitCards_ = [];')) {
  throw 'Refreshed first-run still renders Google account/sync benefit cards.'
}
if (!$introRefreshTsText.Contains('private variation_: Variation = Variation.DEFAULT;')) {
  throw 'Refreshed first-run can still select a variant without the account-free continuation action.'
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party state during browser sign-in audit.'
}
if ($thirdPartyChanges) {
  throw 'Browser sign-in audit detected third_party modifications.'
}

Write-Host 'Ghosium browser-account audit: Google/GAIA browser sign-in disabled; Settings and first-run are account-free while normal website login remains untouched.'
