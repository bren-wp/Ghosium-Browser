param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot,

  [Parameter(Mandatory = $false)]
  [string]$EvidencePath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedRevision = (Get-Content (Join-Path $repoRoot 'ENGINE_SOURCE_REVISION') -Raw).Trim()
$sourceRootResolved = (Resolve-Path $SourceRoot).Path
$actualRevision = (& git -C $sourceRootResolved rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualRevision -ne $expectedRevision) {
  throw "Tab-brand verification requires pinned Chromium source $expectedRevision; found $actualRevision"
}

$requiredFiles = @(
  'components/new_or_sad_tab_strings.grdp',
  'chrome/browser/ui/search/search_tab_helper.cc',
  'chrome/browser/ui/webui/ntp/new_tab_ui.cc',
  'chrome/browser/ui/webui/new_tab_page/new_tab_page_ui.cc'
)
foreach ($relative in $requiredFiles) {
  if (!(Test-Path (Join-Path $sourceRootResolved $relative) -PathType Leaf)) {
    throw "Pinned tab-brand source layout changed; required file is missing: $relative"
  }
}

$tabStringsPath = Join-Path $sourceRootResolved 'components/new_or_sad_tab_strings.grdp'
$tabStrings = [IO.File]::ReadAllText($tabStringsPath)
try {
  [xml]$tabDocument = $tabStrings
} catch {
  throw "Pinned tab/public GRIT is not valid XML: $($_.Exception.Message)"
}

$forbiddenBrand = [regex]::new(
  '(?i)(?:Google\s+Chrome|Google\s+Chromium|Chromium Browser|Chrome Web Store|\bChromium(?=\p{Ll}|\b)|\bChrome(?=\p{Ll}|\b))'
)

function Get-GritMessageTexts {
  param(
    [Parameter(Mandatory = $true)][System.Xml.XmlDocument]$Document,
    [Parameter(Mandatory = $true)][string]$MessageId
  )

  $nodes = @($Document.SelectNodes("//message[@name='$MessageId']"))
  if ($nodes.Count -lt 1) {
    throw "Expected tab/public message is missing from pinned source: $MessageId"
  }

  # GRIT <ex> nodes are translator examples attached to placeholders. They are
  # authoring metadata and never render as product UI. Remove them from a clone
  # before collecting InnerText so this verifier evaluates runtime-visible text
  # symmetrically with the public-branding rewrite.
  $texts = [System.Collections.Generic.List[string]]::new()
  foreach ($node in $nodes) {
    $runtimeNode = $node.CloneNode($true)
    foreach ($example in @($runtimeNode.SelectNodes('.//ex'))) {
      [void]$example.ParentNode.RemoveChild($example)
    }
    $texts.Add([string]$runtimeNode.InnerText)
  }
  return @($texts)
}

$titleIds = @(
  'IDS_DEFAULT_TAB_TITLE',
  'IDS_DOWNLOAD_TAB_TITLE',
  'IDS_SAD_TAB_TITLE',
  'IDS_NEW_TAB_TITLE',
  'IDS_NEW_INCOGNITO_TAB_TITLE'
)
$publicBrandIds = @(
  'IDS_SAD_TAB_RELOAD_RESTART_BROWSER',
  'IDS_NEW_TAB_OTR_NOT_SAVED'
)

$evidenceMessages = [System.Collections.Generic.List[object]]::new()
foreach ($messageId in @($titleIds + $publicBrandIds)) {
  foreach ($messageText in Get-GritMessageTexts -Document $tabDocument -MessageId $messageId) {
    $visible = ([regex]::Replace($messageText, '\s+', ' ')).Trim()
    if ($forbiddenBrand.IsMatch($visible)) {
      throw "Public tab/crash/incognito branding leak remains in ${messageId}: $visible"
    }
    $evidenceMessages.Add([pscustomobject]@{
      id = $messageId
      text = $visible
    })
  }
}

$searchTabHelper = [IO.File]::ReadAllText(
  (Join-Path $sourceRootResolved 'chrome/browser/ui/search/search_tab_helper.cc'))
foreach ($required in @(
  'UpdateTitleForEntry(',
  'GetStringUTF16(IDS_NEW_TAB_TITLE)'
)) {
  if (!$searchTabHelper.Contains($required)) {
    throw "Pinned New Tab title-generation contract changed; missing: $required"
  }
}

$legacyNtp = [IO.File]::ReadAllText(
  (Join-Path $sourceRootResolved 'chrome/browser/ui/webui/ntp/new_tab_ui.cc'))
foreach ($required in @(
  'IDS_NEW_INCOGNITO_TAB_TITLE',
  'IDS_NEW_TAB_TITLE',
  'OverrideTitle(l10n_util::GetStringUTF16(title_resource_id))'
)) {
  if (!$legacyNtp.Contains($required)) {
    throw "Pinned legacy New Tab title contract changed; missing: $required"
  }
}

$modernNtp = [IO.File]::ReadAllText(
  (Join-Path $sourceRootResolved 'chrome/browser/ui/webui/new_tab_page/new_tab_page_ui.cc'))
if ($modernNtp -notmatch '\{"title",\s*IDS_NEW_TAB_TITLE\}') {
  throw 'Pinned modern New Tab title contract changed; localized IDS_NEW_TAB_TITLE binding is missing.'
}

$evidence = [ordered]@{
  schemaVersion = 1
  sourceRevision = $actualRevision
  titleGeneration = [ordered]@{
    searchTabHelperUsesLocalizedNewTabTitle = $true
    legacyNtpUsesLocalizedNormalAndIncognitoTitles = $true
    modernNtpUsesLocalizedNewTabTitle = $true
  }
  gritRuntimeText = [ordered]@{
    translatorExamplesExcluded = $true
  }
  checkedMessages = @($evidenceMessages)
  forbiddenPublicBrandOccurrences = 0
}

if ($EvidencePath) {
  $fullEvidencePath = [IO.Path]::GetFullPath($EvidencePath)
  $directory = Split-Path -Parent $fullEvidencePath
  if ($directory) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
  }
  [IO.File]::WriteAllText(
    $fullEvidencePath,
    ($evidence | ConvertTo-Json -Depth 8),
    [Text.UTF8Encoding]::new($false)
  )
  Write-Host "Ghosium tab-brand evidence: $fullEvidencePath"
}

Write-Host "Ghosium tab-brand contract passed: $($evidenceMessages.Count) title/crash/incognito runtime message variant(s) verified, translator examples excluded, and New Tab title generation remains localized with no public Chrome/Chromium product branding."
