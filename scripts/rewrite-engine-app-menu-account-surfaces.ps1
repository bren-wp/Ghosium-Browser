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
  throw "Refusing to rewrite App Menu account surfaces on an unpinned checkout. Expected $expectedRevision; found $actualRevision"
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

$appMenuView = Join-Path $sourceRootResolved 'chrome/browser/ui/views/toolbar/app_menu.cc'
$appMenuModel = Join-Path $sourceRootResolved 'chrome/browser/ui/toolbar/app_menu_model.cc'
$commandController = Join-Path $sourceRootResolved 'chrome/browser/ui/browser_command_controller.cc'

# The main three-dot menu has its own account-status chip independent of the
# profile bubble. A migrated Chromium profile must remain selectable as a local
# profile, but Ghosium must not label that row Signed in / Verify or decorate it
# with a Google AI membership state.
$appMenuChipReplacement = @'
void AddSignedInChipToProfileMenuItem(
    Profile* /*profile*/,
    views::MenuItemView* /*item*/,
    const int /*horizontal_padding*/,
    std::vector<base::CallbackListSubscription>&
        /*profile_menu_subscription_list*/) {
  // Ghosium profile rows are local-only; browser-account status chips are not
  // part of the product surface.
}
'@.TrimEnd("`r", "`n")

Replace-RequiredRegex `
  -Path $appMenuView `
  -Pattern '(?s)void AddSignedInChipToProfileMenuItem\(.*?\n\}\n\n// AppMenuView' `
  -Replacement ($appMenuChipReplacement + "`n`n// AppMenuView") `
  -AlreadyPresent 'Ghosium profile rows are local-only; browser-account status chips are not' `
  -Description 'App Menu browser-account status chip suppression'

# The profile submenu owns a separate Google Sync section. Keep the profile row,
# local profile switching, guest mode and local customization, but never build
# sign-in, Sync repair, passphrase, cloud upload or Turn on Sync actions.
$syncReplacement = @'
bool ProfileSubMenuModel::BuildSyncSection() {
  // Ghosium does not expose Google browser-account or Sync actions.
  return false;
}
'@.TrimEnd("`r", "`n")

Replace-RequiredRegex `
  -Path $appMenuModel `
  -Pattern '(?s)bool ProfileSubMenuModel::BuildSyncSection\(\) \{.*?\n\}\n\nvoid ProfileSubMenuModel::BuildGuestProfileRow' `
  -Replacement ($syncReplacement + "`n`nvoid ProfileSubMenuModel::BuildGuestProfileRow") `
  -AlreadyPresent 'Ghosium does not expose Google browser-account or Sync actions.' `
  -Description 'App Menu Sync section suppression'

$manageGoogleReplacement = @'
void ProfileSubMenuModel::BuildManageGoogleAccountRow(Profile* /*profile*/) {
  // Ghosium local profiles do not expose a Google Account management action.
}
'@.TrimEnd("`r", "`n")

Replace-RequiredRegex `
  -Path $appMenuModel `
  -Pattern '(?s)void ProfileSubMenuModel::BuildManageGoogleAccountRow\(Profile\* profile\) \{.*?\n\}\n#endif  // !BUILDFLAG\(IS_CHROMEOS\)' `
  -Replacement ($manageGoogleReplacement + "`n#endif  // !BUILDFLAG(IS_CHROMEOS)") `
  -AlreadyPresent 'Ghosium local profiles do not expose a Google Account management action.' `
  -Description 'App Menu Manage Google Account row suppression'

# Defense in depth: these commands also exist independently of menu construction.
# Keep them registered for Chromium-internal compatibility but disabled so an
# extension, accelerator or future menu change cannot make them actionable.
$disabledCommands = @(
  'IDC_SHOW_SYNC_SETTINGS',
  'IDC_SHOW_SYNC_PASSPHRASE_DIALOG',
  'IDC_TURN_ON_SYNC',
  'IDC_SHOW_SIGNIN_WHEN_PAUSED',
  'IDC_SHOW_SIGNIN',
  'IDC_MANAGE_GOOGLE_ACCOUNT',
  'IDC_SHOW_TABS_FROM_OTHER_DEVICES_SIDE_PANEL',
  'IDC_RECENT_TABS_LOGIN_FOR_DEVICE_TABS',
  'IDC_RECENT_TABS_SEE_DEVICE_TABS'
)

foreach ($command in $disabledCommands) {
  $text = [IO.File]::ReadAllText($commandController)
  $pattern = '(?s)command_updater_->UpdateCommandEnabled\(\s*' + [regex]::Escape($command) + '\s*,.*?\);'
  $replacement = "command_updater_->UpdateCommandEnabled($command, false);"

  if ([regex]::IsMatch($text, $pattern)) {
    $updated = [regex]::Replace($text, $pattern, $replacement, 1)
    [IO.File]::WriteAllText($commandController, $updated, [Text.UTF8Encoding]::new($false))
    Write-Host "Disabled browser command: $command"
  } elseif (!$text.Contains($replacement)) {
    throw "Pinned source layout changed; unable to disable browser command $command"
  }
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party state after App Menu account rewrite.'
}
if ($thirdPartyChanges) {
  throw 'App Menu account rewrite modified third_party source.'
}

Write-Host 'Ghosium App Menu account contract applied: local profile controls remain; Google browser-account, Sync and cross-device account actions are suppressed.'
