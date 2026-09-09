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
  throw "Native New Tab verification requires pinned source $expectedRevision; found $actualRevision"
}

$uiPath = Join-Path $sourceRootResolved 'chrome/browser/ui/webui/new_tab_page/new_tab_page_ui.cc'
$logoTsPath = Join-Path $sourceRootResolved 'chrome/browser/resources/new_tab_page/logo.ts'
$logoCssPath = Join-Path $sourceRootResolved 'chrome/browser/resources/new_tab_page/logo.css'
$logoAssetPath = Join-Path $sourceRootResolved 'chrome/browser/resources/new_tab_page/icons/google_logo.svg'
$brandSvg = Join-Path $repoRoot 'engine/branding/ghosium-mark.svg'
foreach ($path in @($uiPath, $logoTsPath, $logoCssPath, $logoAssetPath, $brandSvg)) {
  if (!(Test-Path $path -PathType Leaf)) {
    throw "Native New Tab verification input is missing: $path"
  }
}

$ui = [IO.File]::ReadAllText($uiPath)
foreach ($required in @(
  'source->AddBoolean("prefetchTriggerEnabled", false);',
  'source->AddBoolean("prerenderOnPressEnabled", false);',
  'source->AddBoolean("oneGoogleBarEnabled", false);',
  'source->AddBoolean("logoEnabled", true);',
  'source->AddBoolean("animatedDoodlesEnabled", false);',
  'source->AddBoolean("doodleMuralsEnabled", false);',
  'source->AddBoolean("modulesLoadEnabled", false);',
  'bool microsoft_module_enabled = false;',
  'source->AddBoolean("searchboxShowComposeEntrypoint", false);',
  'source->AddBoolean("ntpRealboxDynamicAiModeButton", false);',
  'source->AddBoolean("searchboxShowComposebox", false);',
  'source->AddBoolean("enableThreadsRail", false);',
  'source->AddBoolean("actionChipsEnabled", false);',
  'source->AddInteger("browserPromoLimit", 0);',
  '.enable_voice_search = false,',
  '.enable_lens_search = false,',
  'IDS_WEBUI_OMNIBOX_PLACEHOLDER_TEXT, u"the web"'
)) {
  if (!$ui.Contains($required)) {
    throw "Ghosium native New Tab invariant is missing: $required"
  }
}

$logoTs = [IO.File]::ReadAllText($logoTsPath)
if (!$logoTs.Contains('this.loaded_ = true;') -or
    $logoTs.Contains('this.pageHandler_.getDoodle().then')) {
  throw 'Native New Tab logo still depends on the remote Doodle fetch path.'
}
if (!$logoTs.Contains('local Ghosium product mark')) {
  throw 'Native New Tab logo source is missing the Ghosium local-brand contract.'
}

$logoCss = [IO.File]::ReadAllText($logoCssPath)
if (!$logoCss.Contains('height: 112px;') -or !$logoCss.Contains('width: 112px;')) {
  throw 'Native New Tab Ghosium logo layout is not square and deterministic.'
}
$expectedHash = (Get-FileHash $brandSvg -Algorithm SHA256).Hash
$actualHash = (Get-FileHash $logoAssetPath -Algorithm SHA256).Hash
if ($actualHash -ne $expectedHash) {
  throw 'Native New Tab logo asset is not the canonical Ghosium mark.'
}

Write-Host 'Ghosium native New Tab privacy/branding contract: OK'
