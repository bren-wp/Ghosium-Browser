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
  throw "Profile Picker verification requires pinned source $expectedRevision; found $actualRevision"
}

$profilePickerUi = Join-Path $sourceRootResolved 'chrome/browser/ui/webui/signin/profile_picker_ui.cc'
if (!(Test-Path $profilePickerUi -PathType Leaf)) {
  throw "Required Profile Picker source is missing: $profilePickerUi"
}

$text = [IO.File]::ReadAllText($profilePickerUi)
foreach ($required in @(
  'html_source->AddBoolean("signInProfileCreationFlowSupported", false);',
  'html_source->AddBoolean("isBrowserSigninAllowed", false);'
)) {
  if (!$text.Contains($required)) {
    throw "Ghosium local-only Profile Picker contract is missing: $required"
  }
}

# The Glic block already contains a static false for force sign-in upstream. The
# normal Profile Picker block must also be static false, so two occurrences are
# expected after the Ghosium transform.
$forceSigninFalseCount = [regex]::Matches(
  $text,
  'html_source->AddBoolean\("isForceSigninEnabled", false\);'
).Count
if ($forceSigninFalseCount -lt 2) {
  throw "Profile Picker force-signin is not disabled in every public picker variant; found $forceSigninFalseCount static false occurrence(s)."
}

foreach ($forbidden in @(
  'html_source->AddBoolean("signInProfileCreationFlowSupported",`n                          AccountConsistencyModeManager::IsDiceSignInAllowed());',
  'html_source->AddBoolean("isBrowserSigninAllowed", IsBrowserSigninAllowed());',
  'signin_util::IsForceSigninEnabled());'
)) {
  if ($text.Contains($forbidden)) {
    throw "An upstream browser-account Profile Picker gate can still become public: $forbidden"
  }
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party state during Profile Picker audit.'
}
if ($thirdPartyChanges) {
  throw 'Profile Picker audit detected third_party modifications.'
}

Write-Host 'Ghosium Profile Picker audit: profile creation is local-only; browser sign-in and force-signin onboarding are unavailable.'
