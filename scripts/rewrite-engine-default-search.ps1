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

$googleFallback = @'
std::unique_ptr<TemplateURLData> GetPrepopulatedFallbackSearch(
    PrefService& prefs,
    const std::vector<raw_ptr<const PrepopulatedEngine>>&
        regional_prepopulated_engines) {
  return FindPrepopulatedEngineInternal(prefs, regional_prepopulated_engines,
                                        google.id,
                                        /*use_first_as_fallback=*/true);
}
'@

$text = [IO.File]::ReadAllText($target)
if (!$text.Contains($googleFallback)) {
  throw 'Pinned Chromium Google fallback changed; refusing an unreviewed default-search modification.'
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
