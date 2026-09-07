param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$config = Get-Content (Join-Path $repoRoot 'engine/branding/product.json') -Raw | ConvertFrom-Json
$sourceRootResolved = (Resolve-Path $SourceRoot).Path

$legalChromiumIds = @(
  '4365115785552740256',
  '7681937895330411637'
)
# IDS_SETTINGS_PEOPLE ("You and Google") is a generic Settings resource rather
# than a Chromium-branded string. Override the translated message by ID so every
# supported locale presents the browser-owned top-level section as Ghosium.
$settingsPeopleTranslationId = '3721119614952978349'
$chromiumWord = [regex]::new('\bChromium\b')
$chromiumProductStem = [regex]::new('\bChromium(?=\p{Ll}|\b)')
$chromeProductStem = [regex]::new('\bChrome(?=\p{Ll}|\b)')

function Get-TranslationLocaleCode {
  param([Parameter(Mandatory = $true)][string]$Locale)

  switch ($Locale) {
    'en-US' { return $null }
    'nb' { return 'no' }
    'he' { return 'iw' }
    default { return $Locale }
  }
}

function Replace-ProductBrandingInBody {
  param(
    [Parameter(Mandatory = $true)][string]$Body,
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$TranslationId,
    [Parameter(Mandatory = $true)][bool]$PreserveChromiumProject
  )

  if ($TranslationId -eq $settingsPeopleTranslationId) {
    return 'Ghosium'
  }

  $updated = $Body
  $updated = $updated.Replace('Chrome Web Store', 'Ghosium Store')
  $updated = $updated.Replace('Chrome Colors', 'Ghosium Colors')
  $updated = $updated.Replace('AI in Chrome', 'AI in Ghosium')
  $updated = $updated.Replace('Gemini in Chromium', 'Gemini in Ghosium')
  $updated = $updated.Replace('Gemini in Chrome', 'Gemini in Ghosium')
  $updated = $updated.Replace('Google Chrome for Testing', 'Ghosium Browser')
  $updated = $updated.Replace('Chrome for Testing', 'Ghosium Browser')
  $updated = $updated.Replace('Google Chrome', 'Ghosium Browser')

  if ($PreserveChromiumProject -and $legalChromiumIds -contains $TranslationId) {
    # These two translated messages are third-party legal attribution. On the
    # first pass replace only the product token. On later normalization passes,
    # keep the remaining upstream-project attribution intact.
    if (!$updated.Contains('Ghosium Browser')) {
      $updated = $chromiumWord.Replace($updated, 'Ghosium Browser', 1)
    }
  } else {
    # Several locales inflect browser brand names. Match lowercase grammatical
    # suffixes such as Chromiuma/Chromiumu/Chromeovih while deliberately not
    # consuming uppercase compounds such as ChromiumOS or ChromeOS.
    $updated = $chromiumProductStem.Replace($updated, 'Ghosium Browser')
    $updated = $chromeProductStem.Replace($updated, 'Ghosium Browser')
  }

  $updated = $updated.Replace('Ghosium Browser browser', 'Ghosium Browser')
  $updated = $updated.Replace('Ghosium Browser Browser', 'Ghosium Browser')
  return $updated
}

function Update-XtbBundle {
  param(
    [Parameter(Mandatory = $true)][string]$Directory,
    [Parameter(Mandatory = $true)][string]$Prefix,
    [Parameter(Mandatory = $true)][bool]$PreserveChromiumProject
  )

  $updatedFiles = 0
  foreach ($locale in @($config.locales.supported)) {
    $fileLocale = Get-TranslationLocaleCode -Locale ([string]$locale)
    if (!$fileLocale) {
      continue
    }

    $path = Join-Path $sourceRootResolved (Join-Path $Directory ($Prefix + $fileLocale + '.xtb'))
    if (!(Test-Path $path -PathType Leaf)) {
      throw "Missing translation bundle for supported locale ${locale}: $path"
    }

    $text = [IO.File]::ReadAllText($path)
    $pattern = '(?s)(<translation\s+id="([0-9]+)"[^>]*>)(.*?)(</translation>)'
    $updated = [regex]::Replace($text, $pattern, {
      param($match)
      $id = $match.Groups[2].Value
      $originalBody = $match.Groups[3].Value
      $body = Replace-ProductBrandingInBody -Body $originalBody -TranslationId $id -PreserveChromiumProject $PreserveChromiumProject

      if ($body -ne $originalBody) {
        $body = [regex]::Replace($body, '[ \t]+(?=\r?\n)', '')
      }

      return $match.Groups[1].Value + $body + $match.Groups[4].Value
    })

    if ($updated -ne $text) {
      [IO.File]::WriteAllText($path, $updated, [Text.UTF8Encoding]::new($false))
      $updatedFiles++
    }
  }

  Write-Host "Updated $updatedFiles localized bundle(s) under $Directory/$Prefix"
}

function Normalize-RewrittenLocalizedResources {
  # Product-link/public-surface routing can touch additional translated bundles.
  # Normalize only files already changed by the reviewed branding pipeline so
  # unrelated source stays byte-for-byte.
  $changed = @(& git -C $sourceRootResolved diff --name-only --diff-filter=ACMRT)
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to enumerate source files changed by Ghosium branding.'
  }

  $normalizedFiles = 0
  foreach ($relative in $changed) {
    if (!$relative -or $relative -match '(^|/)(third_party|test|tests|testing|tools)(/|$)') {
      continue
    }

    $extension = [IO.Path]::GetExtension($relative).ToLowerInvariant()
    if ($extension -notin @('.xtb', '.grd', '.grdp')) {
      continue
    }

    $path = Join-Path $sourceRootResolved $relative
    if (!(Test-Path $path -PathType Leaf)) {
      continue
    }

    $text = [IO.File]::ReadAllText($path)
    $updated = $text

    if ($extension -eq '.xtb') {
      $updated = [regex]::Replace(
        $updated,
        '(?s)(<translation\s+id="([0-9]+)"[^>]*>)(.*?)(</translation>)',
        {
          param($match)
          $id = $match.Groups[2].Value
          $body = Replace-ProductBrandingInBody `
            -Body $match.Groups[3].Value `
            -TranslationId $id `
            -PreserveChromiumProject $true
          return $match.Groups[1].Value + $body + $match.Groups[4].Value
        }
      )
    } else {
      $updated = [regex]::Replace(
        $updated,
        '(?s)(<message\b[^>]*>)(.*?)(</message>)',
        {
          param($match)
          $body = Replace-ProductBrandingInBody `
            -Body $match.Groups[2].Value `
            -TranslationId '' `
            -PreserveChromiumProject $false
          return $match.Groups[1].Value + $body + $match.Groups[3].Value
        }
      )
    }

    $updated = [regex]::Replace($updated, '[ \t]+(?=\r?\n)', '')

    if ($updated -ne $text) {
      [IO.File]::WriteAllText($path, $updated, [Text.UTF8Encoding]::new($false))
      $normalizedFiles++
    }
  }

  Write-Host "Normalized $normalizedFiles additional rewritten localization resource(s)."
}

# Complete the English/public GRIT surface before translations are normalized.
# This fills the gap between branded Chromium-specific strings and generic
# Settings/shared/AI resources visible in the user's actual browser screenshots.
& (Join-Path $PSScriptRoot 'rewrite-engine-public-surfaces.ps1') -SourceRoot $sourceRootResolved
if ($LASTEXITCODE -ne 0) {
  throw 'Ghosium Settings/About/New Tab public-surface branding failed.'
}

Update-XtbBundle -Directory 'chrome/app/resources' -Prefix 'chromium_strings_' -PreserveChromiumProject $false
# Generic Settings, shared Settings and included feature strings (including the
# top-level account/services label) compile from generated_resources_*.xtb.
Update-XtbBundle -Directory 'chrome/app/resources' -Prefix 'generated_resources_' -PreserveChromiumProject $false
Update-XtbBundle -Directory 'components/strings' -Prefix 'components_chromium_strings_' -PreserveChromiumProject $true
Update-XtbBundle -Directory 'extensions/strings' -Prefix 'extensions_strings_' -PreserveChromiumProject $false
Normalize-RewrittenLocalizedResources

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party source status after locale branding.'
}
if ($thirdPartyChanges) {
  throw 'Locale branding modified third_party sources; refusing to continue.'
}

& (Join-Path $PSScriptRoot 'verify-engine-locales.ps1') -SourceRoot $sourceRootResolved
if ($LASTEXITCODE -ne 0) {
  throw 'Ghosium supported locale verification failed.'
}

# Independent public-surface verifier runs only after canonical logo assets and
# locale rewrites exist, so source branding cannot self-certify screenshot-facing
# product identity.
& (Join-Path $PSScriptRoot 'verify-engine-public-surfaces.ps1') -SourceRoot $sourceRootResolved
if ($LASTEXITCODE -ne 0) {
  throw 'Ghosium public-surface verification failed after locale branding.'
}

Write-Host 'Ghosium supported locale and public-surface branding applied and independently verified.'
