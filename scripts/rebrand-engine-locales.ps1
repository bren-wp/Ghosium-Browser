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

  $updated = $Body
  $updated = $updated.Replace('Chrome Web Store', 'Ghosium Store')
  $updated = $updated.Replace('Google Chrome for Testing', 'Ghosium Browser')
  $updated = $updated.Replace('Chrome for Testing', 'Ghosium Browser')
  $updated = $updated.Replace('Google Chrome', 'Ghosium Browser')

  if ($PreserveChromiumProject -and $legalChromiumIds -contains $TranslationId) {
    # These two translated messages are third-party legal attribution. Keep the
    # upstream project name only there; it is not product branding.
    $updated = $chromiumWord.Replace($updated, 'Ghosium Browser', 1)
  } else {
    # Several locales inflect Chromium. Match lowercase grammatical suffixes
    # while leaving unrelated uppercase platform compounds intact. Chrome is
    # replaced only as a standalone brand token so Chromebook/ChromeOS are not
    # accidentally rewritten as malformed product names.
    $updated = $chromiumProductStem.Replace($updated, 'Ghosium Browser')
    $updated = [regex]::Replace($updated, '\bChrome\b', 'Ghosium Browser')
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

  Write-Host "Updated $updatedFiles localized bundle(s) under $Directory"
}

function Normalize-RewrittenLocalizedResources {
  # Product-link routing can touch additional translated bundles outside the
  # three core product-string families. Normalize only files already changed by
  # the reviewed branding pipeline so unrelated source stays byte-for-byte.
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

    # Any file already rewritten by the branding pipeline can inherit trailing
    # spaces from an upstream translated line. Normalize them before diff-check.
    $updated = [regex]::Replace($updated, '[ \t]+(?=\r?\n)', '')

    if ($updated -ne $text) {
      [IO.File]::WriteAllText($path, $updated, [Text.UTF8Encoding]::new($false))
      $normalizedFiles++
    }
  }

  Write-Host "Normalized $normalizedFiles additional rewritten localization resource(s)."
}

Update-XtbBundle -Directory 'chrome/app/resources' -Prefix 'chromium_strings_' -PreserveChromiumProject $false
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

Write-Host 'Ghosium supported locale branding applied and verified.'
