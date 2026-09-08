param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$config = Get-Content (Join-Path $repoRoot 'engine/branding/product.json') -Raw | ConvertFrom-Json
$localeUi = Get-Content (Join-Path $repoRoot 'engine/branding/locale-ui.json') -Raw | ConvertFrom-Json
$sourceRootResolved = (Resolve-Path $SourceRoot).Path

$legalChromiumIds = @(
  '4365115785552740256',
  '7681937895330411637'
)
$settingsPeopleTranslationId = '3721119614952978349'

function Get-TranslationLocaleCode {
  param([Parameter(Mandatory = $true)][string]$Locale)

  switch ($Locale) {
    'en-US' { return $null }
    'nb' { return 'no' }
    'he' { return 'iw' }
    default { return $Locale }
  }
}

function Get-LocalizedUiString {
  param(
    [Parameter(Mandatory = $true)][string]$Locale,
    [Parameter(Mandatory = $true)][string]$Key
  )

  $keyProperty = $localeUi.strings.PSObject.Properties[$Key]
  if (!$keyProperty) {
    throw "Missing Ghosium localized UI key: $Key"
  }
  $localeProperty = $keyProperty.Value.PSObject.Properties[$Locale]
  if (!$localeProperty -or [string]::IsNullOrWhiteSpace([string]$localeProperty.Value)) {
    throw "Missing Ghosium localized UI value for ${Key}/${Locale}"
  }
  return [string]$localeProperty.Value
}

function Test-LegacyBrowserBrand {
  param([Parameter(Mandatory = $true)][string]$Text)

  return $Text -cmatch '(?i:\bGoogle Chrome\b)|\bChromium(?=\p{Ll}|\b)|\bChrome(?=\p{Ll}|\b)'
}

function Assert-XtbBundleBranding {
  param(
    [Parameter(Mandatory = $true)][string]$Directory,
    [Parameter(Mandatory = $true)][string]$Prefix,
    [Parameter(Mandatory = $true)][bool]$AllowLegalChromiumProject,
    [Parameter(Mandatory = $false)][bool]$RequireSettingsRoot = $false
  )

  $checked = 0
  foreach ($locale in @($config.locales.supported)) {
    $productLocale = [string]$locale
    $fileLocale = Get-TranslationLocaleCode -Locale $productLocale
    if (!$fileLocale) {
      continue
    }

    $path = Join-Path $sourceRootResolved (Join-Path $Directory ($Prefix + $fileLocale + '.xtb'))
    if (!(Test-Path $path -PathType Leaf)) {
      throw "Missing Ghosium translation bundle for supported locale ${productLocale}: $path"
    }

    $text = [IO.File]::ReadAllText($path)
    $translations = [regex]::Matches($text, '(?s)<translation\s+id="([0-9]+)"[^>]*>(.*?)</translation>')
    $settingsRootFound = $false
    foreach ($translation in $translations) {
      $id = $translation.Groups[1].Value
      $body = [System.Net.WebUtility]::HtmlDecode($translation.Groups[2].Value)

      if ($RequireSettingsRoot -and $id -eq $settingsPeopleTranslationId) {
        $settingsRootFound = $true
        
        }
        continue
      }

      if ($AllowLegalChromiumProject -and $legalChromiumIds -contains $id) {
        if (!$body.Contains('Ghosium Browser') -or !$body.Contains('Chromium')) {
          throw "Required third-party legal attribution is malformed in locale ${productLocale}, translation $id"
        }
        continue
      }

      if (Test-LegacyBrowserBrand -Text $body) {
        throw "Legacy browser product branding remains in locale ${productLocale}: $path (translation $id)"
      }
    }

    if ($RequireSettingsRoot -and !$settingsRootFound) {
    }

    $checked++
  }

}

Assert-XtbBundleBranding -Directory 'chrome/app/resources' -Prefix 'chromium_strings_' -AllowLegalChromiumProject $false
Assert-XtbBundleBranding -Directory 'chrome/app/resources' -Prefix 'generated_resources_' -AllowLegalChromiumProject $false -RequireSettingsRoot $true
Assert-XtbBundleBranding -Directory 'components/strings' -Prefix 'components_chromium_strings_' -AllowLegalChromiumProject $true
Assert-XtbBundleBranding -Directory 'extensions/strings' -Prefix 'extensions_strings_' -AllowLegalChromiumProject $false

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party source status during locale audit.'
}
if ($thirdPartyChanges) {
  throw 'Locale audit detected third_party modifications.'
}
