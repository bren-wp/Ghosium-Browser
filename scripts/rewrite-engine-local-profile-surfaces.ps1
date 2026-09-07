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
  throw "Refusing to rewrite profile surfaces on an unpinned checkout. Expected $expectedRevision; found $actualRevision"
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

$profileMenu = Join-Path $sourceRootResolved 'chrome/browser/ui/views/profiles/profile_menu_view.cc'
$profileViewUtils = Join-Path $sourceRootResolved 'chrome/browser/ui/profiles/profile_view_utils.cc'

$identityReplacement = @'
  // Ghosium profile identity is local-first. Existing migrated account data may
  // be shown as identity only; no Google browser-account CTA is exposed.
  switch (signin_util::GetSignedInState(identity_manager)) {
    case signin_util::SignedInState::kSignedOut:
    case signin_util::SignedInState::kWebOnlySignedIn:
      break;
    case signin_util::SignedInState::kSignedIn:
    case signin_util::SignedInState::kSyncing:
    case signin_util::SignedInState::kSignInPending:
    case signin_util::SignedInState::kSyncPaused:
      params.email_subtitle = base::UTF8ToUTF16(primary_account_info.email);
      break;
  }

  return params;
'@

$featureButtonsReplacement = @'
void ProfileMenuView::BuildFeatureButtons() {
  CHECK(!profile().IsGuestSession());
  BuildAutofillSettingsButton();
  BuildCustomizeProfileButton();
  MaybeBuildCloseBrowsersButton();
  MaybeBuildSignoutButton();
}

#if BUILDFLAG(ENABLE_DICE_SUPPORT)
'@

# Disable the Google AI-subscription avatar ring at its shared browser helper so
# it cannot leak through the profile bubble, app menu, toolbar avatar or other
# browser-owned profile surfaces.
Replace-RequiredRegex `
  -Path $profileViewUtils `
  -Pattern '(?ms)^bool ShouldShowAvatarGradientRing\(Profile\* profile\) \{\r?\n.*?^\}' `
  -Replacement "bool ShouldShowAvatarGradientRing(Profile* /*profile*/) {`n  // Ghosium has no Google AI-subscription profile decoration.`n  return false;`n}" `
  -AlreadyPresent 'Ghosium has no Google AI-subscription profile decoration.' `
  -Description 'AI subscription avatar-ring suppression'

# The account action state is not needed once browser-level Google sign-in is
# disabled. Removing it also prevents a future accidental default CTA binding.
Replace-RequiredLiteral `
  -Path $profileMenu `
  -OldValue '  CoreAccountInfo account_info_for_signin_action = primary_account_info;' `
  -NewValue '  // Ghosium does not create browser-account sign-in actions.' `
  -Description 'profile sign-in action state removal'

# Suppress sync-error call-to-action cards for migrated Chromium profiles. A
# migrated account may still be displayed as profile identity and can be signed
# out, but Ghosium does not expose Google Sync repair/setup as a product feature.
Replace-RequiredLiteral `
  -Path $profileMenu `
  -OldValue '  syncer::SyncService* service = SyncServiceFactory::GetForProfile(&profile());' `
  -NewValue "  // Ghosium intentionally suppresses Google Sync repair/setup UI.`n  syncer::SyncService* service = nullptr;" `
  -Description 'profile sync-error CTA suppression'

# Replace every account/sync promotion state in the identity card with a passive
# migrated-profile identity. Signed-out profiles stay local; already-associated
# profiles may show their existing email but no sign-in, reauth, sync, upload or
# AI-subscription action is created.
Replace-RequiredRegex `
  -Path $profileMenu `
  -Pattern '(?s)  ActionableItem button_type = ActionableItem::kSigninAccountButton;.*?\n  return params;' `
  -Replacement $identityReplacement `
  -AlreadyPresent 'Ghosium profile identity is local-first.' `
  -Description 'profile identity account/sync CTA removal'

# Keep only browser-local profile controls. Sign out remains as a migration exit
# path for profiles that arrived with a Chromium/Google primary account.
Replace-RequiredRegex `
  -Path $profileMenu `
  -Pattern '(?s)void ProfileMenuView::BuildFeatureButtons\(\) \{.*?\n\}\n\n#if BUILDFLAG\(ENABLE_DICE_SUPPORT\)' `
  -Replacement $featureButtonsReplacement `
  -AlreadyPresent 'Ghosium profile identity is local-first.' `
  -Description 'profile menu cloud/account feature removal'

# Unlike upstream Chromium, a syncing migrated profile must still have an exit
# path. Offer Sign out for any removable browser primary account, not only the
# unconsented/non-sync state.
Replace-RequiredRegex `
  -Path $profileMenu `
  -Pattern '(?s)  const bool add_sign_out_button =\s*HasUnconstentedProfile\(&profile\(\)\) &&\s*!identity_manager->HasPrimaryAccount\(signin::ConsentLevel::kSync\) &&\s*!hide_signout_button_for_managed_profiles;' `
  -Replacement "  const bool add_sign_out_button =`n      identity_manager->HasPrimaryAccount(signin::ConsentLevel::kSignin) &&`n      ChromeSigninClientFactory::GetForProfile(&profile())`n          ->IsClearPrimaryAccountAllowed() &&`n      !hide_signout_button_for_managed_profiles;" `
  -AlreadyPresent 'identity_manager->HasPrimaryAccount(signin::ConsentLevel::kSignin) &&' `
  -Description 'migrated-profile sign-out availability'

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party state after local-profile surface rewrite.'
}
if ($thirdPartyChanges) {
  throw 'Local-profile surface rewrite modified third_party source.'
}

Write-Host 'Ghosium local-profile contract applied: no Google account/sync/AI profile promotion, with a safe migrated-account sign-out path.'
