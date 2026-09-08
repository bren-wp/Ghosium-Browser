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
  throw "App Menu verification requires pinned source $expectedRevision; found $actualRevision"
}

$appMenuView = Join-Path $sourceRootResolved 'chrome/browser/ui/views/toolbar/app_menu.cc'
$appMenuModel = Join-Path $sourceRootResolved 'chrome/browser/ui/toolbar/app_menu_model.cc'
$commandController = Join-Path $sourceRootResolved 'chrome/browser/ui/browser_command_controller.cc'
foreach ($path in @($appMenuView, $appMenuModel, $commandController)) {
  if (!(Test-Path $path -PathType Leaf)) {
    throw "Required Ghosium App Menu source is missing: $path"
  }
}

$viewText = [IO.File]::ReadAllText($appMenuView)
$chipMatch = [regex]::Match(
  $viewText,
  '(?s)void AddSignedInChipToProfileMenuItem\((.*?)\n\}\n\n// AppMenuView'
)
if (!$chipMatch.Success) {
  throw 'Unable to isolate App Menu profile status-chip helper.'
}
$chipBody = $chipMatch.Groups[1].Value
if (!$chipBody.Contains('Ghosium profile rows are local-only; browser-account status chips are not')) {
  throw 'App Menu profile status chip is not under the Ghosium local-only contract.'
}
foreach ($forbidden in @(
  'IDS_PROFILE_ROW_SIGNED_IN_MESSAGE',
  'IDS_PROFILE_ROW_VERIFY_MESSAGE',
  'GetSigninStatusChipString(profile)',
  'ShouldShowAvatarGradientRing(profile)',
  'AddChildView(std::move(profile_chip))'
)) {
  if ($chipBody.Contains($forbidden)) {
    throw "Browser-account state still renders in the main App Menu profile row: $forbidden"
  }
}

$modelText = [IO.File]::ReadAllText($appMenuModel)
$syncMatch = [regex]::Match(
  $modelText,
  '(?s)bool ProfileSubMenuModel::BuildSyncSection\(\) \{(.*?)\n\}\n\nvoid ProfileSubMenuModel::BuildGuestProfileRow'
)
if (!$syncMatch.Success) {
  throw 'Unable to isolate App Menu Sync section.'
}
$syncBody = $syncMatch.Groups[1].Value
if (!$syncBody.Contains('Ghosium does not expose Google browser-account or Sync actions.')) {
  throw 'App Menu Sync section is not explicitly suppressed.'
}
if ($syncBody -notmatch '\breturn false;') {
  throw 'App Menu Sync section can still be created.'
}
foreach ($forbidden in @(
  'IDC_SHOW_SIGNIN',
  'IDC_SHOW_SIGNIN_WHEN_PAUSED',
  'IDC_TURN_ON_SYNC',
  'IDC_SHOW_SYNC_SETTINGS',
  'IDC_SHOW_SYNC_PASSPHRASE_DIALOG',
  'SyncServiceFactory::GetForProfile',
  'IdentityManagerFactory::GetForProfile'
)) {
  if ($syncBody.Contains($forbidden)) {
    throw "Google browser-account/Sync action remains in App Menu Sync builder: $forbidden"
  }
}

$manageMatch = [regex]::Match(
  $modelText,
  '(?s)void ProfileSubMenuModel::BuildManageGoogleAccountRow\(Profile\* /\*profile\*/\) \{(.*?)\n\}'
)
if (!$manageMatch.Success -or
    !$manageMatch.Groups[1].Value.Contains('Ghosium local profiles do not expose a Google Account management action.')) {
  throw 'Manage Google Account can still become a Ghosium App Menu row.'
}
if ($manageMatch.Groups[1].Value.Contains('IDC_MANAGE_GOOGLE_ACCOUNT')) {
  throw 'Manage Google Account command is still added to the profile submenu.'
}

$controllerText = [IO.File]::ReadAllText($commandController)
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
  $pattern = 'command_updater_->UpdateCommandEnabled\(\s*' + [regex]::Escape($command) + '\s*,\s*false\s*\);'
  if ($controllerText -notmatch $pattern) {
    throw "Unowned account/cloud command is not fail-closed in BrowserCommandController: $command"
  }
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party state during App Menu account audit.'
}
if ($thirdPartyChanges) {
  throw 'App Menu account audit detected third_party modifications.'
}

Write-Host 'Ghosium App Menu audit: local profile UI remains, while Google sign-in, Sync, account management and cross-device account commands are absent or disabled.'
