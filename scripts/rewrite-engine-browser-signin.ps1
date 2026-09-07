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
  throw "Refusing to rewrite browser sign-in on an unpinned checkout. Expected $expectedRevision; found $actualRevision"
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
    Write-Host "Applied: $Description"
    return
  }

  if (!$text.Contains($AlreadyPresent)) {
    throw "Pinned source layout changed; unable to apply $Description in $Path"
  }
}

function Replace-RequiredLiteral {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$OldValue,
    [Parameter(Mandatory = $true)][string]$NewValue,
    [Parameter(Mandatory = $true)][string]$Description
  )

  if (!(Test-Path $Path -PathType Leaf)) {
    throw "Pinned source layout changed; $Description target is missing: $Path"
  }

  $text = [IO.File]::ReadAllText($Path)
  if ($text.Contains($OldValue)) {
    [IO.File]::WriteAllText(
      $Path,
      $text.Replace($OldValue, $NewValue),
      [Text.UTF8Encoding]::new($false)
    )
    Write-Host "Applied: $Description"
    return
  }

  if (!$text.Contains($NewValue)) {
    throw "Pinned source layout changed; unable to apply $Description in $Path"
  }
}

$accountConsistency = Join-Path $sourceRootResolved 'chrome/browser/signin/account_consistency_mode_manager.cc'
$personalizationHtml = Join-Path $sourceRootResolved 'chrome/browser/resources/settings/privacy_page/personalization_options.html'
$introUi = Join-Path $sourceRootResolved 'chrome/browser/ui/webui/intro/intro_ui.cc'
$introHtml = Join-Path $sourceRootResolved 'chrome/browser/resources/intro/sign_in_promo.html.ts'
$introTs = Join-Path $sourceRootResolved 'chrome/browser/resources/intro/sign_in_promo.ts'
$introRefreshHtml = Join-Path $sourceRootResolved 'chrome/browser/resources/intro/sign_in_promo_refresh.html.ts'
$introRefreshTs = Join-Path $sourceRootResolved 'chrome/browser/resources/intro/sign_in_promo_refresh.ts'

# Ghosium has no first-party browser account/sync service. Keep normal website
# authentication untouched, but prevent Chromium DICE/GAIA browser sign-in from
# becoming a Ghosium-branded account feature.
Replace-RequiredRegex `
  -Path $accountConsistency `
  -Pattern '(?ms)^bool IsBrowserSigninAllowedByCommandLine\(\) \{\r?\n.*?^\}' `
  -Replacement @'
bool IsBrowserSigninAllowedByCommandLine() {
  // Ghosium intentionally does not expose Google/GAIA browser sign-in.
  return false;
}
'@.TrimEnd("`r", "`n") `
  -AlreadyPresent 'Ghosium intentionally does not expose Google/GAIA browser sign-in.' `
  -Description 'central browser sign-in disablement'

Replace-RequiredLiteral `
  -Path $accountConsistency `
  -OldValue 'registry->RegisterBooleanPref(prefs::kSigninAllowedOnNextStartup, true);' `
  -NewValue 'registry->RegisterBooleanPref(prefs::kSigninAllowedOnNextStartup, false);' `
  -Description 'browser sign-in preference default'

# These controls remain in the DOM so Chromium-internal TypeScript references do
# not break, but they are statically hidden. Dynamic runtime state can no longer
# expose a misleading browser-account setting.
Replace-RequiredLiteral `
  -Path $personalizationHtml `
  -OldValue '?hidden="${!this.chromeSigninUserChoiceInfo_?.shouldShowSettings}"' `
  -NewValue 'hidden' `
  -Description 'Chrome sign-in user-choice Settings control suppression'

Replace-RequiredLiteral `
  -Path $personalizationHtml `
  -OldValue '?hidden="${!this.signinAvailable_}"' `
  -NewValue 'hidden' `
  -Description 'browser sign-in Settings toggle suppression'

# Reuse Chromium's proven first-run continue-without-account path, but turn the
# public sign-in page into a Ghosium welcome page. No Google account, sync or
# cloud-benefit CTA is presented as a Ghosium product.
Replace-RequiredRegex `
  -Path $introUi `
  -Pattern '(?s)const int title_id = is_dont_sign_in_on_gaia_page_variation\s*\? IDS_FRE_GET_YOUR_BROWSER_READY_TITLE\s*: IDS_FRE_SIGN_IN_TITLE_0;' `
  -Replacement 'const int title_id = IDS_FRE_WELCOME_TITLE;' `
  -AlreadyPresent 'const int title_id = IDS_FRE_WELCOME_TITLE;' `
  -Description 'first-run welcome title'

Replace-RequiredLiteral `
  -Path $introUi `
  -OldValue '{"pageSubtitle", IDS_FRE_SIGN_IN_SUBTITLE_0},' `
  -NewValue '{"pageSubtitle", IDS_PRODUCT_DESCRIPTION},' `
  -Description 'first-run browser-only subtitle'

Replace-RequiredRegex `
  -Path $introUi `
  -Pattern '(?s)source->AddLocalizedString\(\s*"declineSignInButtonTitle",\s*base::FeatureList::IsEnabled\(\s*switches::kProfileCreationDeclineSigninCTAExperiment\)\s*\? IDS_FRE_STAY_SIGNED_OUT_BUTTON_TITLE\s*: IDS_FRE_DECLINE_SIGN_IN_BUTTON_TITLE\);' `
  -Replacement 'source->AddLocalizedString("declineSignInButtonTitle",`n                             IDS_FRE_WELCOME_START_BUTTON_LABEL);' `
  -AlreadyPresent 'source->AddLocalizedString("declineSignInButtonTitle",`n                             IDS_FRE_WELCOME_START_BUTTON_LABEL);' `
  -Description 'first-run Start browsing action'

# Do not render account/sync benefit cards on either first-run variant.
Replace-RequiredRegex `
  -Path $introTs `
  -Pattern '(?s)this\.benefitCards_ = \[.*?\n    \];' `
  -Replacement 'this.benefitCards_ = [];' `
  -AlreadyPresent 'this.benefitCards_ = [];' `
  -Description 'legacy first-run account benefit removal'

Replace-RequiredRegex `
  -Path $introRefreshTs `
  -Pattern '(?s)this\.benefitCards_ = \[.*?\n    \];' `
  -Replacement 'this.benefitCards_ = [];' `
  -AlreadyPresent 'this.benefitCards_ = [];' `
  -Description 'refreshed first-run account benefit removal'

# Force the refreshed layout onto the variant that always renders the
# continue-without-account button, then remove the account sign-in CTA itself.
Replace-RequiredRegex `
  -Path $introRefreshTs `
  -Pattern 'private variation_: Variation =\s*loadTimeData\.getInteger\(''signInPromoVariation''\) as Variation;' `
  -Replacement 'private variation_: Variation = Variation.DEFAULT;' `
  -AlreadyPresent 'private variation_: Variation = Variation.DEFAULT;' `
  -Description 'account-free first-run layout selection'

foreach ($path in @($introHtml, $introRefreshHtml)) {
  Replace-RequiredRegex `
    -Path $path `
    -Pattern '(?s)\s*<cr-button id="acceptSignInButton".*?</cr-button>' `
    -Replacement "`n    <!-- Ghosium: Google/GAIA browser sign-in CTA intentionally removed. -->" `
    -AlreadyPresent 'Google/GAIA browser sign-in CTA intentionally removed' `
    -Description "first-run account CTA removal: $path"
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party state after browser sign-in suppression.'
}
if ($thirdPartyChanges) {
  throw 'Browser sign-in suppression modified third_party source.'
}

Write-Host 'Ghosium browser-account contract applied: Google/GAIA browser sign-in is disabled and first-run is account-free.'
