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

  # The upstream Google account/sync Settings page is hidden from Ghosium's
  # public menu. Keep a neutral internal route title rather than implying that
  # Google account services are owned by Ghosium.
  if ($TranslationId -eq $settingsPeopleTranslationId) {
    return 'Profile'
  }

  $updated = $Body
  $updated = $updated.Replace('Chrome Web Store', 'Ghosium Store')
  $updated = $updated.Replace('Chrome Colors', 'Ghosium Colors')
  # Google/Gemini AI Settings are hidden from Ghosium. Shared localized strings
  # that remain compiled are neutralized, never relabeled as a Ghosium AI service.
  $updated = $updated.Replace('AI in Chrome', 'AI features')
  $updated = $updated.Replace('Gemini in Chromium', 'Gemini')
  $updated = $updated.Replace('Gemini in Chrome', 'Gemini')
  $updated = $updated.Replace('You and Google', 'Profile')
  $updated = $updated.Replace('Google Chrome for Testing', 'Ghosium Browser')
  $updated = $updated.Replace('Chrome for Testing', 'Ghosium Browser')
  $updated = $updated.Replace('Google Chrome', 'Ghosium Browser')

  if ($PreserveChromiumProject -and $legalChromiumIds -contains $TranslationId) {
    if (!$updated.Contains('Ghosium Browser')) {
      $updated = $chromiumWord.Replace($updated, 'Ghosium Browser', 1)
    }
  } else {
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

$publicSurfaceRequired = @(
  'chrome/app/settings_strings.grdp',
  'chrome/app/shared_settings_strings.grdp',
  'chrome/app/glic_strings.grdp',
  'chrome/browser/extensions/extension_ui_util.cc',
  'chrome/browser/resources/settings/settings_menu/settings_menu.html',
  'chrome/browser/resources/settings/settings_menu/settings_menu.ts',
  'chrome/browser/resources/settings/route.ts',
  'chrome/browser/ui/webui/settings/settings_ui.cc',
  'chrome/browser/resources/settings/privacy_page/personalization_options.html',
  'chrome/browser/resources/new_tab_page/app.html',
  'chrome/browser/ui/webui/new_tab_footer/footer_context_menu.cc',
  'chrome/browser/ui/browser_actions.cc',
  'chrome/browser/signin/account_consistency_mode_manager.cc',
  'chrome/browser/ui/webui/intro/intro_ui.cc',
  'chrome/browser/resources/intro/sign_in_promo.html.ts',
  'chrome/browser/resources/intro/sign_in_promo.ts',
  'chrome/browser/resources/intro/sign_in_promo_refresh.html.ts',
  'chrome/browser/resources/intro/sign_in_promo_refresh.ts',
  'components/desktop_to_mobile_promos/features.cc'
)
$completePublicSurfaceSource = $true
foreach ($relative in $publicSurfaceRequired) {
  if (!(Test-Path (Join-Path $sourceRootResolved $relative) -PathType Leaf)) {
    $completePublicSurfaceSource = $false
    break
  }
}

if ($completePublicSurfaceSource) {
  & (Join-Path $PSScriptRoot 'rewrite-engine-public-surfaces.ps1') -SourceRoot $sourceRootResolved
  if ($LASTEXITCODE -ne 0) {
    throw 'Ghosium Settings/About/New Tab public-surface branding failed.'
  }

  & (Join-Path $PSScriptRoot 'rewrite-engine-upstream-public-actions.ps1') -SourceRoot $sourceRootResolved
  if ($LASTEXITCODE -ne 0) {
    throw 'Ghosium upstream Chromium/Google browser-action suppression failed.'
  }

  & (Join-Path $PSScriptRoot 'rewrite-engine-disable-unowned-promos.ps1') -SourceRoot $sourceRootResolved
  if ($LASTEXITCODE -ne 0) {
    throw 'Ghosium unowned Chromium mobile-promo suppression failed.'
  }

  & (Join-Path $PSScriptRoot 'rewrite-engine-browser-signin.ps1') -SourceRoot $sourceRootResolved
  if ($LASTEXITCODE -ne 0) {
    throw 'Ghosium Google/GAIA browser sign-in suppression failed.'
  }
} else {
  Write-Host 'Narrow sparse engine audit detected; complete public-surface source transform is delegated to Ghosium Public Surface Contract.'
}

Update-XtbBundle -Directory 'chrome/app/resources' -Prefix 'chromium_strings_' -PreserveChromiumProject $false
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

if ($completePublicSurfaceSource) {
  & (Join-Path $PSScriptRoot 'verify-engine-public-surfaces.ps1') -SourceRoot $sourceRootResolved
  if ($LASTEXITCODE -ne 0) {
    throw 'Ghosium public-surface verification failed after locale branding.'
  }

  & (Join-Path $PSScriptRoot 'verify-engine-upstream-public-actions.ps1') -SourceRoot $sourceRootResolved
  if ($LASTEXITCODE -ne 0) {
    throw 'Ghosium upstream Chromium/Google browser-action verification failed.'
  }

  & (Join-Path $PSScriptRoot 'verify-engine-disable-unowned-promos.ps1') -SourceRoot $sourceRootResolved
  if ($LASTEXITCODE -ne 0) {
    throw 'Ghosium unowned Chromium mobile-promo verification failed.'
  }

  & (Join-Path $PSScriptRoot 'verify-engine-browser-signin.ps1') -SourceRoot $sourceRootResolved
  if ($LASTEXITCODE -ne 0) {
    throw 'Ghosium Google/GAIA browser sign-in verification failed.'
  }
}

Write-Host 'Ghosium supported locale branding verified; complete public surfaces, hidden upstream actions, unowned mobile promos and browser-account entry points are independently verified whenever their source set is present.'
