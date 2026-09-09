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
  throw "Privacy-default verification requires pinned source $expectedRevision; found $actualRevision"
}

$checks = @(
  @('components/content_settings/core/browser/cookie_settings.cc', 'static_cast<int>(CookieControlsMode::kBlockThirdParty),', 'static_cast<int>(CookieControlsMode::kIncognitoOnly),'),
  @('chrome/browser/profiles/profile.cc', "prefs::kSearchSuggestEnabled,`n      false,", "prefs::kSearchSuggestEnabled,`n      true,"),
  @('chrome/browser/preloading/preloading_prefs.cc', 'static_cast<int>(NetworkPredictionOptions::kDisabled),', 'static_cast<int>(NetworkPredictionOptions::kDefault),'),
  @('chrome/browser/net/profile_network_context_service.cc', "registry->RegisterBooleanPref(embedder_support::kAlternateErrorPagesEnabled,`n                                false);", "registry->RegisterBooleanPref(embedder_support::kAlternateErrorPagesEnabled,`n                                true);")
)
foreach ($check in $checks) {
  $path = Join-Path $sourceRootResolved $check[0]
  if (!(Test-Path $path -PathType Leaf)) {
    throw "Privacy verification source file is missing: $($check[0])"
  }
  $text = [IO.File]::ReadAllText($path)
  if (!$text.Contains($check[1])) {
    throw "Required Ghosium privacy default is missing in $($check[0]): $($check[1])"
  }
  if ($text.Contains($check[2])) {
    throw "Upstream privacy-weaker default remains active in $($check[0]): $($check[2])"
  }
}

$spellcheck = [IO.File]::ReadAllText((Join-Path $sourceRootResolved 'chrome/browser/spellchecker/spellcheck_factory.cc'))
if (!$spellcheck.Contains('spellcheck::prefs::kSpellCheckUseSpellingService, false')) {
  throw 'Online spelling service is not disabled by default.'
}

Write-Host 'Ghosium native privacy-default contract: OK'
