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
  throw "Refusing to rewrite Profile Picker on an unpinned checkout. Expected $expectedRevision; found $actualRevision"
}

$profilePickerUi = Join-Path $sourceRootResolved 'chrome/browser/ui/webui/signin/profile_picker_ui.cc'
if (!(Test-Path $profilePickerUi -PathType Leaf)) {
  throw "Pinned source layout changed; Profile Picker UI source is missing: $profilePickerUi"
}

function Replace-RequiredRegex {
  param(
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string]$Replacement,
    [Parameter(Mandatory = $true)][string]$AlreadyPresent,
    [Parameter(Mandatory = $true)][string]$Description
  )

  $text = [IO.File]::ReadAllText($profilePickerUi)
  if ([regex]::IsMatch($text, $Pattern)) {
    $updated = [regex]::Replace($text, $Pattern, $Replacement, 1)
    [IO.File]::WriteAllText($profilePickerUi, $updated, [Text.UTF8Encoding]::new($false))
    Write-Host "Applied: $Description"
    return
  }

  if (!$text.Contains($AlreadyPresent)) {
    throw "Pinned Chromium Profile Picker layout changed; unable to apply $Description"
  }
}

# Keep Chromium's local profile customization flow intact, but make every public
# route into GAIA/browser sign-in unreachable in Ghosium.
Replace-RequiredRegex `
  -Pattern '(?s)html_source->AddBoolean\(\s*"signInProfileCreationFlowSupported",\s*AccountConsistencyModeManager::IsDiceSignInAllowed\(\)\);' `
  -Replacement 'html_source->AddBoolean("signInProfileCreationFlowSupported", false);' `
  -AlreadyPresent 'html_source->AddBoolean("signInProfileCreationFlowSupported", false);' `
  -Description 'Profile Picker browser sign-in flow disablement'

Replace-RequiredRegex `
  -Pattern 'html_source->AddBoolean\("isBrowserSigninAllowed", IsBrowserSigninAllowed\(\)\);' `
  -Replacement 'html_source->AddBoolean("isBrowserSigninAllowed", false);' `
  -AlreadyPresent 'html_source->AddBoolean("isBrowserSigninAllowed", false);' `
  -Description 'Profile Picker browser sign-in availability disablement'

# Force-signin is an upstream browser-account policy surface. With no Ghosium
# account service it must not redirect local profile creation into a dead GAIA
# flow. Enterprise web authentication and ordinary site login remain untouched.
Replace-RequiredRegex `
  -Pattern '(?s)html_source->AddBoolean\("isForceSigninEnabled",\s*signin_util::IsForceSigninEnabled\(\)\);' `
  -Replacement 'html_source->AddBoolean("isForceSigninEnabled", false);' `
  -AlreadyPresent 'html_source->AddBoolean("isForceSigninEnabled", false);' `
  -Description 'Profile Picker force-signin disablement'

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party state after Profile Picker rewrite.'
}
if ($thirdPartyChanges) {
  throw 'Profile Picker local-only rewrite modified third_party source.'
}

Write-Host 'Ghosium Profile Picker contract applied: Add profile remains local-only with no browser-account or force-signin onboarding.'
