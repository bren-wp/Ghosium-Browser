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
  throw "Privacy-default hardening requires pinned source $expectedRevision; found $actualRevision"
}

function Replace-RequiredLiteral {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$OldValue,
    [Parameter(Mandatory = $true)][string]$NewValue
  )
  if (!(Test-Path $Path -PathType Leaf)) {
    throw "Required privacy-default source file is missing: $Path"
  }
  $text = [IO.File]::ReadAllText($Path)
  $oldCount = ([regex]::Matches($text, [regex]::Escape($OldValue))).Count
  $newCount = ([regex]::Matches($text, [regex]::Escape($NewValue))).Count
  if ($oldCount -eq 1 -and $newCount -eq 0) {
    [IO.File]::WriteAllText($Path, $text.Replace($OldValue, $NewValue), [Text.UTF8Encoding]::new($false))
    return
  }
  if ($oldCount -eq 0 -and $newCount -eq 1) {
    Write-Host "Privacy anchor already hardened: $Path"
    return
  }
  throw "Pinned privacy anchor changed in $Path. Expected exactly one upstream anchor or one exact hardened value; upstream=$oldCount hardened=$newCount"
}

$cookieSettings = Join-Path $sourceRootResolved 'components/content_settings/core/browser/cookie_settings.cc'
$profile = Join-Path $sourceRootResolved 'chrome/browser/profiles/profile.cc'
$preloading = Join-Path $sourceRootResolved 'chrome/browser/preloading/preloading_prefs.cc'
$networkContext = Join-Path $sourceRootResolved 'chrome/browser/net/profile_network_context_service.cc'
$spellcheck = Join-Path $sourceRootResolved 'chrome/browser/spellchecker/spellcheck_factory.cc'

Replace-RequiredLiteral -Path $cookieSettings `
  -OldValue 'static_cast<int>(CookieControlsMode::kIncognitoOnly),' `
  -NewValue 'static_cast<int>(CookieControlsMode::kBlockThirdParty),'
Replace-RequiredLiteral -Path $profile `
  -OldValue "prefs::kSearchSuggestEnabled,`n      true," `
  -NewValue "prefs::kSearchSuggestEnabled,`n      false,"
Replace-RequiredLiteral -Path $preloading `
  -OldValue 'static_cast<int>(NetworkPredictionOptions::kDefault),' `
  -NewValue 'static_cast<int>(NetworkPredictionOptions::kDisabled),'
Replace-RequiredLiteral -Path $networkContext `
  -OldValue "registry->RegisterBooleanPref(embedder_support::kAlternateErrorPagesEnabled,`n                                true);" `
  -NewValue "registry->RegisterBooleanPref(embedder_support::kAlternateErrorPagesEnabled,`n                                false);"

# Online spell-check upload is already privacy-safe by default in pinned
# Chromium. Assert it rather than rewriting a security-sensitive subsystem.
$spellcheckText = [IO.File]::ReadAllText($spellcheck)
if (!$spellcheckText.Contains('spellcheck::prefs::kSpellCheckUseSpellingService, false')) {
  throw 'Pinned Chromium online spell-check service no longer defaults to disabled; explicit review required.'
}

Write-Host 'Ghosium native privacy defaults applied: third-party cookies blocked, suggestions/preloading/alternate-error service disabled.'
