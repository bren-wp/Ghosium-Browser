param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot
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
    throw "Required Ghosium public-branding configuration is missing: $required"
  }
}

$actualRevision = (& git -C $sourceRootResolved rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualRevision -ne $expectedRevision) {
  throw "Refusing complete public-branding rewrite on an unpinned checkout. Expected $expectedRevision; found $actualRevision"
}

$policy = Get-Content $policyPath -Raw | ConvertFrom-Json
$productConfig = Get-Content $productConfigPath -Raw | ConvertFrom-Json
if ([int]$policy.schemaVersion -ne 1) {
  throw "Unsupported public-branding allowlist schema: $($policy.schemaVersion)"
}

# These are distinct third-party/platform product names, not Chromium browser
# branding. Protect the narrow, known compounds so a stem replacement can still
# handle localized Chromium/Chrome inflections without creating names such as
# "Ghosium Browserbook". Chrome Web Store is intentionally not protected: it is
# a browser-owned destination and is rewritten to Ghosium Store.
$preservedThirdPartyNamePattern = [regex]::new(
  '(?i)\bChrome(?:book|box|base|bit|cast|OS|Vox|Driver)\p{L}*\b'
)

function Test-ExcludedSourcePath {
  param([Parameter(Mandatory = $true)][string]$RelativePath)

  if ($RelativePath -match '(^|/)(third_party|test|tests|testing|tools|android|ash|chromeos|ios)(/|$)') {
    return $true
  }

  $fileName = [IO.Path]::GetFileName($RelativePath)
  if ($fileName -match '(?i)chromeos' -or
      $RelativePath -match '(?i)(^|/)google_chrome[^/]*($|/)' -or
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

function Rewrite-ProductText {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Text)

  $updated = $Text
  $protected = [System.Collections.Generic.List[object]]::new()
  $properNames = @($preservedThirdPartyNamePattern.Matches($updated) | ForEach-Object { $_.Value } | Select-Object -Unique)
  for ($index = 0; $index -lt $properNames.Count; $index++) {
    $name = [string]$properNames[$index]
    $token = "__GHOSIUM_PRESERVE_PRODUCT_${index}__"
    $protected.Add([pscustomobject]@{ token = $token; value = $name })
    $updated = $updated.Replace($name, $token)
  }

  $updated = $updated.Replace('Chrome Web Store', 'Ghosium Store')
  $updated = $updated.Replace('Google Chrome for Testing', 'Ghosium Browser')
  $updated = $updated.Replace('Chrome for Testing', 'Ghosium Browser')
  $updated = $updated.Replace('Google Chromium', 'Ghosium Browser')
  $updated = $updated.Replace('Google Chrome', 'Ghosium Browser')
  $updated = $updated.Replace('Chromium Browser', 'Ghosium Browser')
  $updated = [regex]::Replace($updated, '\bChromium(?=\p{Ll}|\b)', 'Ghosium Browser')
  $updated = [regex]::Replace($updated, '\bChrome(?=\p{Ll}|\b)', 'Ghosium Browser')
  $updated = $updated.Replace('Ghosium Browser Browser', 'Ghosium Browser')
  $updated = $updated.Replace('Ghosium Browser browser', 'Ghosium Browser')

  foreach ($entry in $protected) {
    $updated = $updated.Replace([string]$entry.token, [string]$entry.value)
  }
  return $updated
}

function Rewrite-VisibleXmlText {
  param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Body)

  # <ex> nodes are translator examples embedded in placeholders. They are not
  # runtime UI and must not be treated as browser-branding copy.
  $parts = [regex]::Split($Body, '(<[^>]+>)')
  $insideExample = $false
  for ($index = 0; $index -lt $parts.Count; $index++) {
    $part = $parts[$index]
    if ($part.StartsWith('<')) {
      if ($part -match '^<ex(?:\s|>)') {
        $insideExample = $true
      } elseif ($part -match '^</ex\s*>') {
        $insideExample = $false
      }
      continue
    }
    if (!$insideExample) {
      $parts[$index] = Rewrite-ProductText -Text $part
    }
  }
  return ($parts -join '')
}

$pathspecs = @(
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
$tracked = @(& git -C $sourceRootResolved ls-files -- $pathspecs)
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to enumerate tracked first-party GRIT/XTB resources for complete public-branding rewrite.'
}

$changedFiles = 0
$changedMessages = 0
$changedTranslations = 0
$legalPreserved = 0
$scannedFiles = 0

foreach ($relative in @($tracked | Sort-Object -Unique)) {
  if ([string]::IsNullOrWhiteSpace($relative) -or
      (Test-ExcludedSourcePath -RelativePath $relative) -or
      !(Test-SupportedTranslationFile -RelativePath $relative)) {
    continue
  }

  $path = Join-Path $sourceRootResolved $relative
  if (!(Test-Path $path -PathType Leaf)) {
    # Sparse source-audit checkouts intentionally have index entries that are
    # not materialized. Full source builds materialize every production file.
    continue
  }

  $scannedFiles++
  $text = [IO.File]::ReadAllText($path)
  $updated = $text
  $extension = [IO.Path]::GetExtension($relative).ToLowerInvariant()

  if ($extension -in @('.grd', '.grdp')) {
    $pattern = '(?s)(<message\b(?<attrs>[^>]*)>)(?<body>.*?)(</message>)'
    $updated = [regex]::Replace($updated, $pattern, {
      param($match)
      $nameMatch = [regex]::Match($match.Groups['attrs'].Value, '\bname="([^"]+)"')
      if (!$nameMatch.Success) {
        return $match.Value
      }

      $messageId = $nameMatch.Groups[1].Value
      if (Test-LegalGritMessage -RelativePath $relative -MessageId $messageId) {
        $script:legalPreserved++
        return $match.Value
      }

      $body = $match.Groups['body'].Value
      $rewrittenBody = Rewrite-VisibleXmlText -Body $body
      if ($rewrittenBody -ne $body) {
        $script:changedMessages++
      }
      return $match.Groups[1].Value + $rewrittenBody + $match.Groups[4].Value
    })
  } elseif ($extension -eq '.xtb') {
    $pattern = '(?s)(<translation\s+id="(?<id>[0-9]+)"[^>]*>)(?<body>.*?)(</translation>)'
    $updated = [regex]::Replace($updated, $pattern, {
      param($match)
      $translationId = $match.Groups['id'].Value
      if (Test-LegalTranslation -RelativePath $relative -TranslationId $translationId) {
        $script:legalPreserved++
        return $match.Value
      }

      $body = $match.Groups['body'].Value
      $rewrittenBody = Rewrite-VisibleXmlText -Body $body
      if ($rewrittenBody -ne $body) {
        $script:changedTranslations++
      }
      return $match.Groups[1].Value + $rewrittenBody + $match.Groups[4].Value
    })
  }

  if ($updated -ne $text) {
    [IO.File]::WriteAllText($path, $updated, [Text.UTF8Encoding]::new($false))
    $changedFiles++
  }
}

if ($scannedFiles -lt 1) {
  throw 'Complete public-branding rewrite did not find any materialized first-party GRIT/XTB resources.'
}

$thirdPartyChanges = @(& git -C $sourceRootResolved status --porcelain=v1 -- third_party)
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party state after complete public-branding rewrite.'
}
if ($thirdPartyChanges.Count -gt 0) {
  throw 'Complete public-branding rewrite touched third_party source; refusing to continue.'
}

Write-Host "Complete Ghosium public-string rewrite scanned $scannedFiles file(s), changed $changedFiles file(s), rewrote $changedMessages GRIT message(s) and $changedTranslations supported translation(s), and preserved $legalPreserved explicit legal attribution occurrence(s)."
