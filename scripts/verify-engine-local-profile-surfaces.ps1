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
  throw "Local-profile verification requires pinned source $expectedRevision; found $actualRevision"
}

$profileMenu = Join-Path $sourceRootResolved 'chrome/browser/ui/views/profiles/profile_menu_view.cc'
$profileViewUtils = Join-Path $sourceRootResolved 'chrome/browser/ui/profiles/profile_view_utils.cc'
$subscriptionService = Join-Path $sourceRootResolved 'components/subscription_eligibility/subscription_eligibility_service.cc'
foreach ($path in @($profileMenu, $profileViewUtils, $subscriptionService)) {
  if (!(Test-Path $path -PathType Leaf)) {
    throw "Required Ghosium local-profile source is missing: $path"
  }
}

$subscriptionText = [IO.File]::ReadAllText($subscriptionService)
if ($subscriptionText -notmatch '(?s)int32_t SubscriptionEligibilityService::GetAiSubscriptionTier\(\) const \{\s*// Ghosium does not consume Google AI subscription entitlements\.\s*return 0;\s*\}') {
  throw 'Google AI subscription entitlement can still drive Ghosium browser UI.'
}

$utilsText = [IO.File]::ReadAllText($profileViewUtils)
if ($utilsText -notmatch '(?s)bool ShouldShowAvatarGradientRing\(Profile\* /\*profile\*/\) \{\s*// Ghosium has no Google AI-subscription profile decoration\.\s*return false;\s*\}') {
  throw 'Google AI-subscription avatar decoration can still become public in Ghosium.'
}

$menuText = [IO.File]::ReadAllText($profileMenu)
if (!$menuText.Contains('// Ghosium does not create browser-account sign-in actions.')) {
  throw 'Profile sign-in action state was not removed.'
}
if (!$menuText.Contains('// Ghosium intentionally suppresses Google Sync repair/setup UI.')) {
  throw 'Migrated profile Sync repair/setup CTA suppression is missing.'
}
if (!$menuText.Contains('syncer::SyncService* service = nullptr;')) {
  throw 'Profile identity can still create Sync error actions.'
}
if (!$menuText.Contains('// Ghosium profile identity is local-first.')) {
  throw 'Local-first Ghosium identity state is missing.'
}

$identityMatch = [regex]::Match(
  $menuText,
  '(?s)ProfileMenuView::GetIdentitySectionParams\(const ProfileAttributesEntry& entry\) \{(.*?)\n\}\n\nvoid ProfileMenuView::BuildIdentityWithCallToAction'
)
if (!$identityMatch.Success) {
  throw 'Unable to isolate Ghosium profile identity function for verification.'
}
$identityBody = $identityMatch.Groups[1].Value
foreach ($forbidden in @(
  'IDS_PROFILE_MENU_SIGNIN_PROMO_BUTTON',
  'IDS_PROFILES_DICE_WEB_ONLY_SIGNIN_BUTTON',
  'IDS_PROFILE_MENU_SYNC_PROMO_BUTTON_LABEL',
  'OnSigninButtonClicked',
  'OnBatchUploadButtonClicked',
  'AvatarBadgeView::GetAvatarBadgeLabel',
  'SubscriptionEligibilityServiceFactory::GetForProfile'
)) {
  if ($identityBody.Contains($forbidden)) {
    throw "Unowned account/sync/AI identity CTA remains public: $forbidden"
  }
}

$featureMatch = [regex]::Match(
  $menuText,
  '(?s)void ProfileMenuView::BuildFeatureButtons\(\) \{(.*?)\n\}\n\n#if BUILDFLAG\(ENABLE_DICE_SUPPORT\)'
)
if (!$featureMatch.Success) {
  throw 'Unable to isolate Ghosium profile feature-button function.'
}
$featureBody = $featureMatch.Groups[1].Value
foreach ($required in @(
  'BuildAutofillSettingsButton();',
  'BuildCustomizeProfileButton();',
  'MaybeBuildCloseBrowsersButton();',
  'MaybeBuildSignoutButton();'
)) {
  if (!$featureBody.Contains($required)) {
    throw "Required local Ghosium profile control is missing: $required"
  }
}
foreach ($forbidden in @(
  'MaybeBuildCrossDeviceSigninButton',
  'MaybeBuildBatchUploadButton',
  'MaybeBuildManageGoogleAccountButton',
  'MaybeBuildChromeAccountSettingsButton',
  'MaybeBuildChromeAccountSettingsButtonWithSync',
  'MaybeBuildGoogleServicesSettingsButton'
)) {
  if ($featureBody.Contains($forbidden)) {
    throw "Google/cloud profile feature is still publicly built by Ghosium: $forbidden"
  }
}

if ($menuText -notmatch '(?s)const bool add_sign_out_button =\s*identity_manager->HasPrimaryAccount\(signin::ConsentLevel::kSignin\) &&\s*ChromeSigninClientFactory::GetForProfile\(&profile\(\)\)\s*->IsClearPrimaryAccountAllowed\(\) &&\s*!hide_signout_button_for_managed_profiles;') {
  throw 'Migrated Google/Chromium browser account does not have a safe Ghosium Sign out exit path.'
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party state during local-profile audit.'
}
if ($thirdPartyChanges) {
  throw 'Local-profile audit detected third_party modifications.'
}

Write-Host 'Ghosium local-profile audit: local controls remain; Google sign-in/sync/cloud/AI promotion and AI subscription entitlements are absent, with Sign out preserved for migrated accounts.'
