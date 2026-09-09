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
  throw "Refusing to verify default search on an unpinned checkout. Expected $expectedRevision; found $actualRevision"
}

$target = Join-Path $sourceRootResolved 'components/search_engines/template_url_prepopulate_data.cc'
if (!(Test-Path $target -PathType Leaf)) {
  throw "Pinned Chromium search-engine source is missing: $target"
}

$text = [IO.File]::ReadAllText($target)

# Verify the reviewed Google fallback structurally instead of requiring one
# whitespace-identical source rendering. Chromium frequently reflows C++
# parameters without changing behavior; an exact multiline Contains() check can
# therefore reject the same pinned implementation. Keep this fail-closed by
# anchoring the exact function and requiring every behavior-defining token.
$functionPattern = '(?ms)std::unique_ptr<TemplateURLData>\s+GetPrepopulatedFallbackSearch\s*\((?<parameters>.*?)\)\s*\{(?<body>.*?)\n\}'
$functionMatch = [regex]::Match($text, $functionPattern)
if (!$functionMatch.Success) {
  throw 'Pinned Chromium Google fallback function shape changed; refusing an unreviewed default-search modification.'
}

$parameters = $functionMatch.Groups['parameters'].Value
$body = $functionMatch.Groups['body'].Value
foreach ($requiredParameter in @(
  'PrefService& prefs',
  'regional_prepopulated_engines'
)) {
  if (!$parameters.Contains($requiredParameter)) {
    throw "Pinned Chromium Google fallback parameters changed; missing reviewed token: $requiredParameter"
  }
}

foreach ($requiredBodyToken in @(
  'FindPrepopulatedEngineInternal',
  'prefs',
  'regional_prepopulated_engines',
  'google.id',
  '/*use_first_as_fallback=*/true'
)) {
  if (!$body.Contains($requiredBodyToken)) {
    throw "Pinned Chromium Google fallback behavior changed; missing reviewed token: $requiredBodyToken"
  }
}

# The reviewed fallback is a single direct return expression. Do not silently
# accept additional provider selection, mutation, branching, or side effects.
$normalizedBody = [regex]::Replace($body, '\s+', ' ').Trim()
if ($normalizedBody -notmatch '^return\s+FindPrepopulatedEngineInternal\s*\(' -or
    $normalizedBody -notmatch '\);$') {
  throw 'Pinned Chromium Google fallback body is no longer the reviewed direct return expression.'
}
if ($normalizedBody -match '\b(if|switch|for|while)\s*\(') {
  throw 'Pinned Chromium Google fallback gained unreviewed control flow.'
}

foreach ($forbidden in @(
  'Ghosium Search',
  'search.ghosium.com',
  'prepopulate_id = 1101',
  '9e993bd9-c256-42d7-a1b1-000000001101'
)) {
  if ($text.Contains($forbidden)) {
    throw "Retired Ghosium Search integration remains in engine source: $forbidden"
  }
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party source state after default-search verification.'
}
if ($thirdPartyChanges) {
  throw 'Default-search verification found modified third_party sources; refusing to continue.'
}

Write-Host 'Google Search remains the reviewed Chromium distribution fallback: OK'
