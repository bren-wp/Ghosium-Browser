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
$policyPath = Join-Path $repoRoot 'engine/branding/public-branding-allowlist.json'
$productConfigPath = Join-Path $repoRoot 'engine/branding/product.json'
$sourceRootResolved = (Resolve-Path $SourceRoot).Path

foreach ($required in @($policyPath, $productConfigPath)) {
  if (!(Test-Path $required -PathType Leaf)) {
    throw "Required Ghosium public-branding verification configuration is missing: $required"
  }
}

$actualRevision = (& git -C $sourceRootResolved rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualRevision -ne $expectedRevision) {
  throw "Complete public-branding verification requires pinned engine source $expectedRevision; found $actualRevision"
}

$policy = Get-Content $policyPath -Raw | ConvertFrom-Json
$productConfig = Get-Content $productConfigPath -Raw | ConvertFrom-Json
if ([int]$policy.schemaVersion -ne 1) {
  throw "Unsupported public-branding allowlist schema: $($policy.schemaVersion)"
}

function Test-ExcludedSourcePath {
  param([Parameter(Mandatory = $true)][string]$RelativePath)

  if ($RelativePath -match '(^|/)(third_party|test|tests|testing|tools|android|ash|chromeos)(/|$)') {
    return $true
  }
  if ($RelativePath -match '(?i)(^|/)google_chrome[^/]*($|/)' -or
      $RelativePath -match '(?i)(^|/)chrome_for_testing[^/]*($|/)') {
    return $true
  }
  return $false
}

function Get-SupportedTranslationLocaleCodes {
  $codes = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  foreach ($localeValue in @($productConfig.locales.supported)) {
    $locale = [string]$localeValue
    switch ($locale) {
      'en-US' { continue }
      'nb' { [void]$codes.Add('no'); continue }
      'he' { [void]$codes.Add('iw'); continue }
      default { [void]$codes.Add($locale) }
    }
  }
  return $codes
}

$supportedTranslationLocales = Get-SupportedTranslationLocaleCodes

function Test-SupportedTranslationFile {
  param([Parameter(Mandatory = $true)][string]$RelativePath)

  if (![string]::Equals([IO.Path]::GetExtension($RelativePath), '.xtb', [StringComparison]::OrdinalIgnoreCase)) {
    return $true
  }

  $stem = [IO.Path]::GetFileNameWithoutExtension($RelativePath)
  foreach ($locale in $supportedTranslationLocales) {
    if ($stem.EndsWith("_$locale", [StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }
  return $false
}

function Test-LegalGritMessage {
  param(
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [Parameter(Mandatory = $true)][string]$MessageId
  )

  foreach ($entry in @($policy.legalGritMessages)) {
    if ([string]$entry.path -eq $RelativePath -and [string]$entry.id -eq $MessageId) {
      return $true
    }
  }
  return $false
}

function Test-LegalTranslation {
  param(
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [Parameter(Mandatory = $true)][string]$TranslationId
  )

  foreach ($entry in @($policy.legalTranslations)) {
    if ($RelativePath -like [string]$entry.pathGlob -and [string]$entry.id -eq $TranslationId) {
      return $true
    }
  }
  return $false
}

function Get-VisibleXmlText {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Body)

  $withoutTags = [regex]::Replace($Body, '<[^>]+>', '')
  return [System.Net.WebUtility]::HtmlDecode($withoutTags)
}

function Get-LineNumber {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [Parameter(Mandatory = $true)][int]$Offset
  )

  if ($Offset -le 0) {
    return 1
  }
  return 1 + ([regex]::Matches($Text.Substring(0, $Offset), "`n")).Count
}

function Add-Violation {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Surface,
    [Parameter(Mandatory = $true)][string]$Identifier,
    [Parameter(Mandatory = $true)][int]$Line,
    [Parameter(Mandatory = $true)][string]$Text
  )

  $compact = ([regex]::Replace($Text, '\s+', ' ')).Trim()
  if ($compact.Length -gt 240) {
    $compact = $compact.Substring(0, 240) + '...'
  }

  $script:violations.Add([pscustomobject]@{
    category = 'public-branding-must-change'
    path = $Path
    surface = $Surface
    identifier = $Identifier
    line = $Line
    text = $compact
  })
}

$forbiddenVisibleBrand = [regex]::new(
  '(?i)(?:Google\s+Chrome|Google\s+Chromium|Chromium Browser|Chrome Web Store|\bChromium(?=\p{Ll}|\b)|\bChrome(?=\p{Ll}|\b))'
)
$forbiddenLiteralBrand = [regex]::new(
  '(?:Google\s+Chrome|Google\s+Chromium|Chromium Browser|Chrome Web Store|\bChromium\b|\bChrome\b)'
)

$sparseValue = @(& git -C $sourceRootResolved config --bool core.sparseCheckout 2>$null)
$isSparseCheckout = ($LASTEXITCODE -eq 0 -and ($sparseValue -join '').Trim() -eq 'true')

$requiredFullSourceRoots = @(
  'chrome/app',
  'chrome/browser/resources',
  'chrome/browser/resources/new_tab_page',
  'chrome/browser/resources/settings',
  'chrome/browser/resources/history',
  'chrome/browser/resources/bookmarks',
  'chrome/browser/resources/downloads',
  'chrome/browser/resources/extensions',
  'chrome/browser/resources/password_manager',
  'chrome/browser/resources/print_preview',
  'chrome/browser/resources/pdf',
  'chrome/browser/resources/signin',
  'components/security_interstitials',
  'components/error_page',
  'extensions/strings',
  'ui/webui/resources'
)
if (!$isSparseCheckout) {
  foreach ($relativeRoot in $requiredFullSourceRoots) {
    $fullRoot = Join-Path $sourceRootResolved $relativeRoot
    if (!(Test-Path $fullRoot -PathType Container)) {
      throw "Pinned full-source layout changed; required public surface root is missing: $relativeRoot"
    }
  }
}

$violations = [System.Collections.Generic.List[object]]::new()
$legalPreserved = [System.Collections.Generic.List[object]]::new()
$scannedGritFiles = 0
$scannedWebUiFiles = 0
$scannedMessages = 0
$scannedTranslations = 0

$gritPathspecs = @(
  ':(glob)chrome/**/*.grd',
  ':(glob)chrome/**/*.grdp',
  ':(glob)chrome/**/*.xtb',
  ':(glob)components/**/*.grd',
  ':(glob)components/**/*.grdp',
  ':(glob)components/**/*.xtb',
  ':(glob)content/**/*.grd',
  ':(glob)content/**/*.grdp',
  ':(glob)content/**/*.xtb',
  ':(glob)extensions/**/*.grd',
  ':(glob)extensions/**/*.grdp',
  ':(glob)extensions/**/*.xtb',
  ':(glob)ui/**/*.grd',
  ':(glob)ui/**/*.grdp',
  ':(glob)ui/**/*.xtb'
)
$gritFiles = @(& git -C $sourceRootResolved ls-files -- $gritPathspecs)
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to enumerate first-party GRIT/XTB resources during complete public-branding verification.'
}

foreach ($relative in @($gritFiles | Sort-Object -Unique)) {
  if ([string]::IsNullOrWhiteSpace($relative) -or
      (Test-ExcludedSourcePath -RelativePath $relative) -or
      !(Test-SupportedTranslationFile -RelativePath $relative)) {
    continue
  }

  $path = Join-Path $sourceRootResolved $relative
  if (!(Test-Path $path -PathType Leaf)) {
    continue
  }

  $scannedGritFiles++
  $text = [IO.File]::ReadAllText($path)
  $extension = [IO.Path]::GetExtension($relative).ToLowerInvariant()

  if ($extension -in @('.grd', '.grdp')) {
    $matches = [regex]::Matches($text, '(?s)<message\b(?<attrs>[^>]*)>(?<body>.*?)</message>')
    foreach ($match in $matches) {
      $nameMatch = [regex]::Match($match.Groups['attrs'].Value, '\bname="([^"]+)"')
      if (!$nameMatch.Success) {
        continue
      }
      $scannedMessages++
      $messageId = $nameMatch.Groups[1].Value
      if (Test-LegalGritMessage -RelativePath $relative -MessageId $messageId) {
        $legalPreserved.Add([pscustomobject]@{
          category = 'legal-third-party-attribution-keep'
          path = $relative
          identifier = $messageId
        })
        continue
      }

      $visible = Get-VisibleXmlText -Body $match.Groups['body'].Value
      if ($forbiddenVisibleBrand.IsMatch($visible)) {
        Add-Violation -Path $relative -Surface 'grit-message' -Identifier $messageId -Line (Get-LineNumber -Text $text -Offset $match.Index) -Text $visible
      }
    }
  } elseif ($extension -eq '.xtb') {
    $matches = [regex]::Matches($text, '(?s)<translation\s+id="(?<id>[0-9]+)"[^>]*>(?<body>.*?)</translation>')
    foreach ($match in $matches) {
      $scannedTranslations++
      $translationId = $match.Groups['id'].Value
      if (Test-LegalTranslation -RelativePath $relative -TranslationId $translationId) {
        $legalPreserved.Add([pscustomobject]@{
          category = 'legal-third-party-attribution-keep'
          path = $relative
          identifier = $translationId
        })
        continue
      }

      $visible = Get-VisibleXmlText -Body $match.Groups['body'].Value
      if ($forbiddenVisibleBrand.IsMatch($visible)) {
        Add-Violation -Path $relative -Surface 'localized-translation' -Identifier $translationId -Line (Get-LineNumber -Text $text -Offset $match.Index) -Text $visible
      }
    }
  }
}

$webUiPathspecs = @(
  ':(glob)chrome/browser/resources/**/*.html',
  ':(glob)chrome/browser/resources/**/*.htm',
  ':(glob)chrome/browser/resources/**/*.ts',
  ':(glob)chrome/browser/resources/**/*.js',
  ':(glob)chrome/browser/resources/**/*.mjs',
  ':(glob)chrome/browser/resources/**/*.json',
  ':(glob)chrome/browser/resources/**/*.webmanifest',
  ':(glob)chrome/browser/resources/**/*.svg',
  ':(glob)components/security_interstitials/**/*.html',
  ':(glob)components/security_interstitials/**/*.ts',
  ':(glob)components/security_interstitials/**/*.js',
  ':(glob)components/security_interstitials/**/*.json',
  ':(glob)components/error_page/**/*.html',
  ':(glob)components/error_page/**/*.ts',
  ':(glob)components/error_page/**/*.js',
  ':(glob)components/password_manager/**/*.html',
  ':(glob)components/password_manager/**/*.ts',
  ':(glob)components/password_manager/**/*.js',
  ':(glob)ui/webui/resources/**/*.html',
  ':(glob)ui/webui/resources/**/*.ts',
  ':(glob)ui/webui/resources/**/*.js',
  ':(glob)ui/webui/resources/**/*.mjs',
  ':(glob)ui/webui/resources/**/*.json',
  ':(glob)ui/webui/resources/**/*.svg'
)
$webUiFiles = @(& git -C $sourceRootResolved ls-files -- $webUiPathspecs)
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to enumerate public WebUI resources during complete public-branding verification.'
}

$scriptLiteralPattern = [regex]::new(@'
(?s)(?<quote>["'`])(?<value>(?:\\.|(?!\k<quote>).)*?)\k<quote>
'@.Trim())

foreach ($relative in @($webUiFiles | Sort-Object -Unique)) {
  if ([string]::IsNullOrWhiteSpace($relative) -or (Test-ExcludedSourcePath -RelativePath $relative)) {
    continue
  }

  $path = Join-Path $sourceRootResolved $relative
  if (!(Test-Path $path -PathType Leaf)) {
    continue
  }

  $scannedWebUiFiles++
  $text = [IO.File]::ReadAllText($path)
  $withoutBlockComments = [regex]::Replace($text, '(?s)<!--.*?-->|/\*.*?\*/', '')
  $extension = [IO.Path]::GetExtension($relative).ToLowerInvariant()

  if ($extension -in @('.html', '.htm', '.svg')) {
    $lineOffset = 0
    foreach ($line in ($withoutBlockComments -split "`n")) {
      $trimmed = $line.Trim()
      if ($trimmed.StartsWith('//')) {
        $lineOffset += $line.Length + 1
        continue
      }
      if ($forbiddenLiteralBrand.IsMatch($line)) {
        Add-Violation -Path $relative -Surface 'webui-markup' -Identifier '<literal>' -Line (Get-LineNumber -Text $withoutBlockComments -Offset $lineOffset) -Text $line
      }
      $lineOffset += $line.Length + 1
    }
    continue
  }

  foreach ($literal in $scriptLiteralPattern.Matches($withoutBlockComments)) {
    $value = $literal.Groups['value'].Value
    if ($forbiddenLiteralBrand.IsMatch($value)) {
      Add-Violation -Path $relative -Surface 'webui-literal' -Identifier '<literal>' -Line (Get-LineNumber -Text $withoutBlockComments -Offset $literal.Index) -Text $value
    }
  }
}

if ($scannedGritFiles -lt 1) {
  throw 'Complete public-branding verifier did not inspect any materialized GRIT/XTB resource.'
}
if (!$isSparseCheckout -and $scannedWebUiFiles -lt 1) {
  throw 'Complete public-branding verifier did not inspect any full-source WebUI resource.'
}

$evidence = [ordered]@{
  schemaVersion = 1
  sourceRevision = $actualRevision
  sparseCheckout = $isSparseCheckout
  scanned = [ordered]@{
    gritFiles = $scannedGritFiles
    webUiFiles = $scannedWebUiFiles
    gritMessages = $scannedMessages
    localizedTranslations = $scannedTranslations
  }
  allowed = @($legalPreserved)
  violations = @($violations)
}

if ($EvidencePath) {
  $evidenceFullPath = [IO.Path]::GetFullPath($EvidencePath)
  $evidenceDirectory = Split-Path -Parent $evidenceFullPath
  if ($evidenceDirectory) {
    New-Item -ItemType Directory -Force -Path $evidenceDirectory | Out-Null
  }
  [IO.File]::WriteAllText(
    $evidenceFullPath,
    ($evidence | ConvertTo-Json -Depth 8),
    [Text.UTF8Encoding]::new($false)
  )
  Write-Host "Ghosium public-branding audit evidence: $evidenceFullPath"
}

if ($violations.Count -gt 0) {
  Write-Host 'Forbidden public Chrome/Chromium branding occurrences:'
  foreach ($violation in @($violations | Select-Object -First 50)) {
    Write-Host (" - {0}:{1} [{2}/{3}] {4}" -f $violation.path, $violation.line, $violation.surface, $violation.identifier, $violation.text)
  }
  throw "Complete Ghosium public-branding audit found $($violations.Count) forbidden public Chrome/Chromium occurrence(s)."
}

$thirdPartyChanges = @(& git -C $sourceRootResolved status --porcelain=v1 -- third_party)
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party source state during complete public-branding verification.'
}
if ($thirdPartyChanges.Count -gt 0) {
  throw 'Ghosium public-branding transformation modified third_party source.'
}

Write-Host "Complete Ghosium public-branding audit passed: $scannedMessages GRIT messages, $scannedTranslations supported translations and $scannedWebUiFiles WebUI resources checked; $($legalPreserved.Count) explicit legal attribution occurrence(s) preserved."
