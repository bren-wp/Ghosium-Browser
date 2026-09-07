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
  throw "Upstream public-action verification requires pinned source $expectedRevision; found $actualRevision"
}

$browserActions = Join-Path $sourceRootResolved 'chrome/browser/ui/browser_actions.cc'
if (!(Test-Path $browserActions -PathType Leaf)) {
  throw "Required browser action registry is missing: $browserActions"
}
$text = [IO.File]::ReadAllText($browserActions)

$requiredHiddenBlocks = @(
  [pscustomobject]@{
    Name = 'Customize Chromium side panel'
    Pattern = '(?s)SidePanelAction\(\s*SidePanelEntryId::kCustomizeChrome,.*?kActionSidePanelShowCustomizeChrome,\s*bwi,\s*false\)\s*\.SetVisible\(false\)\s*\.Build\(\)'
  },
  [pscustomobject]@{
    Name = 'Google GEIC/Gemini side panel'
    Pattern = '(?s)SidePanelAction\(\s*SidePanelEntryId::kGeic,.*?kActionSidePanelShowGeic,\s*bwi,\s*false\)\s*\.SetVisible\(false\)\s*\.Build\(\)'
  },
  [pscustomobject]@{
    Name = 'Google Glic/Gemini side panel'
    Pattern = '(?s)SidePanelAction\(\s*SidePanelEntryId::kGlic,.*?kActionSidePanelShowGlic,\s*bwi,\s*false\)\s*\.SetVisible\(false\)\s*\.Build\(\)'
  }
)

foreach ($contract in $requiredHiddenBlocks) {
  if ($text -notmatch $contract.Pattern) {
    throw "Ghosium public-action contract failed: $($contract.Name) is not permanently hidden."
  }
}

$forbiddenVisibility = @(
  '(?s)SidePanelEntryId::kGeic,.*?kActionSidePanelShowGeic,\s*bwi,\s*false\)\s*\.SetVisible\(true\)',
  '(?s)SidePanelEntryId::kGlic,.*?kActionSidePanelShowGlic,\s*bwi,\s*false\)\s*\.SetVisible\(glic::GlicEnabling::ShouldShowGlicButton\(profile\)\)',
  '(?s)SidePanelEntryId::kCustomizeChrome,.*?kActionSidePanelShowCustomizeChrome,\s*bwi,\s*false\)\s*\.Build\(\)'
)
foreach ($pattern in $forbiddenVisibility) {
  if ($text -match $pattern) {
    throw "An upstream Chromium/Google browser action can still become public: $pattern"
  }
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party state during upstream public-action audit.'
}
if ($thirdPartyChanges) {
  throw 'Upstream public-action audit detected third_party modifications.'
}

Write-Host 'Ghosium upstream public-action audit: Customize Chromium, GEIC and Glic/Gemini are registered only as hidden internal actions.'
