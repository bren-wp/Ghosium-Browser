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
  throw "Refusing to suppress upstream public actions on an unpinned checkout. Expected $expectedRevision; found $actualRevision"
}

$browserActions = Join-Path $sourceRootResolved 'chrome/browser/ui/browser_actions.cc'
if (!(Test-Path $browserActions -PathType Leaf)) {
  throw "Pinned source layout changed; browser action registry is missing: $browserActions"
}

function Force-BuilderActionHidden {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$ActionPattern,
    [Parameter(Mandatory = $true)][string]$LegacyVisibilityPattern,
    [Parameter(Mandatory = $true)][string]$Description
  )

  $text = [IO.File]::ReadAllText($Path)
  $hiddenPattern = '(?s)(' + $ActionPattern + ')\s*\.SetVisible\(false\)'
  if ([regex]::IsMatch($text, $hiddenPattern)) {
    return
  }

  $pattern = '(?s)(' + $ActionPattern + ')\s*(' + $LegacyVisibilityPattern + ')'
  if (![regex]::IsMatch($text, $pattern)) {
    throw "Pinned Chromium action layout changed; unable to suppress $Description."
  }

  $updated = [regex]::Replace(
    $text,
    $pattern,
    {
      param($match)
      $replacement = $match.Groups[1].Value + "`n          .SetVisible(false)"
      # The Customize block had no visibility setter: its matched legacy tail is
      # the terminal .Build(). Re-add it after inserting SetVisible(false).
      # GEIC/Glic match only their old visibility setter, so their .Build()
      # remains outside the replacement and must not be duplicated.
      if ($match.Groups[2].Value -match '\.Build\(\)') {
        $replacement += "`n          .Build()"
      }
      return $replacement
    },
    1
  )
  [IO.File]::WriteAllText($Path, $updated, [Text.UTF8Encoding]::new($false))
  Write-Host "Suppressed public upstream action: $Description"
}

function Force-AiOverlayHidden {
  param([Parameter(Mandatory = $true)][string]$Path)

  $text = [IO.File]::ReadAllText($Path)
  $blockStart = 'if\s*\(glic::GlicEnabling::IsProfileEligible\(profile\)\s*&&\s*base::FeatureList::IsEnabled\(features::kAiOverlayDialog\)\)\s*\{'
  $hiddenPattern = '(?s)' + $blockStart + '.*?kActionShowAiOverlayDialog.*?item->SetVisible\(false\);.*?root_action_item_->AddChild\(std::move\(item\)\);'
  if ($text -match $hiddenPattern) {
    return
  }

  $pattern = '(?s)(' + $blockStart + '.*?kActionShowAiOverlayDialog.*?)(\s*root_action_item_->AddChild\(std::move\(item\)\);)'
  if ($text -notmatch $pattern) {
    throw 'Pinned Chromium action layout changed; unable to suppress Google AI overlay toolbar action.'
  }

  $updated = [regex]::Replace(
    $text,
    $pattern,
    {
      param($match)
      return $match.Groups[1].Value + "`n    item->SetVisible(false);" + $match.Groups[2].Value
    },
    1
  )
  [IO.File]::WriteAllText($Path, $updated, [Text.UTF8Encoding]::new($false))
  Write-Host 'Suppressed public upstream action: Google AI overlay toolbar action'
}

# Keep action IDs registered for Chromium-internal callers, but make these
# upstream product/service entry points permanently invisible in Ghosium.
Force-BuilderActionHidden `
  -Path $browserActions `
  -ActionPattern 'SidePanelAction\(\s*SidePanelEntryId::kCustomizeChrome,.*?kActionSidePanelShowCustomizeChrome,\s*bwi,\s*false\)' `
  -LegacyVisibilityPattern '\.Build\(\)' `
  -Description 'Customize Chromium side panel'

Force-BuilderActionHidden `
  -Path $browserActions `
  -ActionPattern 'SidePanelAction\(\s*SidePanelEntryId::kGeic,.*?kActionSidePanelShowGeic,\s*bwi,\s*false\)' `
  -LegacyVisibilityPattern '\.SetVisible\(true\)' `
  -Description 'Google GEIC/Gemini side panel'

Force-BuilderActionHidden `
  -Path $browserActions `
  -ActionPattern 'SidePanelAction\(\s*SidePanelEntryId::kGlic,.*?kActionSidePanelShowGlic,\s*bwi,\s*false\)' `
  -LegacyVisibilityPattern '\.SetVisible\(glic::GlicEnabling::ShouldShowGlicButton\(profile\)\)' `
  -Description 'Google Glic/Gemini side panel'

Force-AiOverlayHidden -Path $browserActions

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party state after upstream action suppression.'
}
if ($thirdPartyChanges) {
  throw 'Upstream public-action suppression modified third_party source.'
}

Write-Host 'Ghosium upstream browser actions suppressed: Customize Chromium, GEIC, Glic/Gemini and AI overlay are not public.'
