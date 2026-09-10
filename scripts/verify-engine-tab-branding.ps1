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
$forbiddenBrand = [regex]::new(
  '(?i)(?:Google\s+Chrome|Google\s+Chromium|Chromium Browser|Chrome Web Store|\bChromium(?=\p{Ll}|\b)|\bChrome(?=\p{Ll}|\b))'
)

function Get-GritMessageBodies {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [Parameter(Mandatory = $true)][string]$MessageId
  )

  $escaped = [regex]::Escape($MessageId)
  $matches = [regex]::Matches(
    $Text,
    '(?s)<message\b[^>]*name="' + $escaped + '"[^>]*>(?<body>.*?)</message>'
  )
  if ($matches.Count -lt 1) {
    throw "Expected tab/public message is missing from pinned source: $MessageId"
  }
  return @($matches | ForEach-Object { $_.Groups['body'].Value })
}

function Get-VisibleText {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Body)

  return [System.Net.WebUtility]::HtmlDecode(
    [regex]::Replace($Body, '<[^>]+>', '')
  ).Trim()
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
  foreach ($body in Get-GritMessageBodies -Text $tabStrings -MessageId $messageId) {
    $visible = Get-VisibleText -Body $body
    if ($forbiddenBrand.IsMatch($visible)) {
      throw "Public tab/crash/incognito branding leak remains in ${messageId}: $visible"
    }
    $evidenceMessages.Add([pscustomobject]@{
      id = $messageId
      text = ([regex]::Replace($visible, '\s+', ' ')).Trim()
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

Write-Host "Ghosium tab-brand contract passed: $($evidenceMessages.Count) title/crash/incognito message variant(s) verified and New Tab title generation remains localized, with no public Chrome/Chromium product branding."
