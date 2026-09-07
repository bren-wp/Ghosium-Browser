param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$config = Get-Content (Join-Path $repoRoot 'engine/branding/product.json') -Raw | ConvertFrom-Json
$expectedCommit = (Get-Content (Join-Path $repoRoot 'ENGINE_SOURCE_REVISION') -Raw).Trim()
$sourceRootResolved = (Resolve-Path $SourceRoot).Path

$actualCommit = (& git -C $sourceRootResolved rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualCommit -ne $expectedCommit) {
  throw "Refusing to rewrite product links in an unpinned checkout. Expected $expectedCommit; found $actualCommit"
}

function Replace-KnownLiteral {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$OldValue,
    [Parameter(Mandatory = $true)][string]$NewValue
  )

  $text = [IO.File]::ReadAllText($Path)
  if ($text.Contains($OldValue)) {
    $text = $text.Replace($OldValue, $NewValue)
    [IO.File]::WriteAllText($Path, $text, [Text.UTF8Encoding]::new($false))
    return
  }
  if (!$text.Contains($NewValue)) {
    throw "Neither expected old nor new product-link literal was found in ${Path}: $OldValue"
  }
}

function Replace-KnownRegex {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string]$Replacement,
    [Parameter(Mandatory = $true)][string]$AlreadyPresent
  )

  $text = [IO.File]::ReadAllText($Path)
  $regex = [regex]::new($Pattern)
  if ($regex.IsMatch($text)) {
    $text = $regex.Replace($text, $Replacement, 1)
    [IO.File]::WriteAllText($Path, $text, [Text.UTF8Encoding]::new($false))
    return
  }
  if (!$text.Contains($AlreadyPresent)) {
    throw "Expected product-link block was not found in $Path"
  }
}

function Assert-LiteralAbsent {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Literal
  )

  if ([IO.File]::ReadAllText($Path).Contains($Literal)) {
    throw "Legacy product-generated URL remains in ${Path}: $Literal"
  }
}

function Get-RelativeSourcePath {
  param([Parameter(Mandatory = $true)][string]$FullName)

  $relative = $FullName.Substring($sourceRootResolved.Length)
  $relative = $relative.TrimStart([char[]]@('\', '/'))
  return ($relative -replace '\\', '/')
}

$urlConstants = Join-Path $sourceRootResolved 'chrome/common/url_constants.h'
$customizeHandler = Join-Path $sourceRootResolved 'chrome/browser/ui/webui/side_panel/customize_chrome/customize_chrome_page_handler.cc'
$chromePages = Join-Path $sourceRootResolved 'chrome/browser/ui/chrome_pages.cc'
$extensionsUi = Join-Path $sourceRootResolved 'chrome/browser/ui/webui/extensions/extensions_ui.cc'
$aboutPageTs = Join-Path $sourceRootResolved 'chrome/browser/resources/settings/about_page/about_page.ts'

foreach ($path in @($urlConstants, $customizeHandler, $chromePages, $extensionsUi, $aboutPageTs)) {
  if (!(Test-Path $path -PathType Leaf)) {
    throw "Pinned source layout changed; product-link target is missing: $path"
  }
}

# Core Help entry points.
Replace-KnownLiteral -Path $urlConstants -OldValue '"https://support.google.com/chrome?p=help&ctx=keyboard"' -NewValue '"https://ghosium.com/support"'
Replace-KnownLiteral -Path $urlConstants -OldValue '"https://support.google.com/chrome?p=help&ctx=menu"' -NewValue '"https://ghosium.com/support"'
Replace-KnownLiteral -Path $urlConstants -OldValue '"https://support.google.com/chrome?p=help&ctx=settings"' -NewValue '"https://ghosium.com/support"'

# New-tab Customize > Change theme. Keep the established extension-store
# security model untouched; only the user-facing navigation target is changed.
Replace-KnownLiteral -Path $customizeHandler -OldValue 'GURL("https://chromewebstore.google.com/category/themes")' -NewValue 'GURL("https://store.ghosium.com/")'

# App menu / extensions menu Store navigation. Do not repoint the internal
# extension-store security helper because it participates in origin/CORS/site-
# isolation decisions. Ghosium Store gets its own reviewed trust model.
Replace-KnownLiteral -Path $chromePages -OldValue 'GURL webstore_url = extension_urls::GetNewWebstoreLaunchURL();' -NewValue 'GURL webstore_url("https://store.ghosium.com/");'
Replace-KnownLiteral -Path $chromePages -OldValue 'browser, extension_urls::AppendUtmSource(webstore_url, utm_source_value));' -NewValue 'browser, webstore_url);'

# Ghosium extensions user-facing navigation/help strings.
$suspiciousReplacement = "source->AddString(`"suspiciousInstallHelpUrl`",`n                    base::ASCIIToUTF16(`"https://ghosium.com/security`"));"
Replace-KnownRegex -Path $extensionsUi -Pattern '(?s)source->AddString\(\s*"suspiciousInstallHelpUrl",\s*base::ASCIIToUTF16\(google_util::AppendGoogleLocaleParam\(\s*GURL\(chrome::kRemoveNonCWSExtensionURL\),\s*g_browser_process->GetApplicationLocale\(\)\)\s*\.spec\(\)\)\);' -Replacement $suspiciousReplacement -AlreadyPresent 'https://ghosium.com/security'

$enhancedReplacement = "source->AddString(`"enhancedSafeBrowsingWarningHelpUrl`",`n                    `"https://ghosium.com/security`"));"
Replace-KnownRegex -Path $extensionsUi -Pattern '(?s)source->AddString\(\s*"enhancedSafeBrowsingWarningHelpUrl",\s*chrome::kCwsEnhancedSafeBrowsingLearnMoreURL\s*\);' -Replacement $enhancedReplacement -AlreadyPresent 'https://ghosium.com/security'

$getMoreReplacement = "source->AddString(`"getMoreExtensionsUrl`",`n                    base::ASCIIToUTF16(`"https://store.ghosium.com/`"));"
Replace-KnownRegex -Path $extensionsUi -Pattern '(?s)source->AddString\(\s*"getMoreExtensionsUrl",\s*base::ASCIIToUTF16\(\s*google_util::AppendGoogleLocaleParam\(\s*extension_urls::AppendUtmSource\(\s*extension_urls::GetWebstoreExtensionsCategoryURL\(\),\s*extension_urls::kExtensionsSidebarUtmSource\),\s*g_browser_process->GetApplicationLocale\(\)\s*\)\s*\.spec\(\)\)\);' -Replacement $getMoreReplacement -AlreadyPresent 'https://store.ghosium.com/'

$guidanceReplacement = "source->AddString(`"modernWebGuidanceURL`",`n                    base::ASCIIToUTF16(`"https://ghosium.com/support`"));"
Replace-KnownRegex -Path $extensionsUi -Pattern '(?s)source->AddString\(\s*"modernWebGuidanceURL",\s*base::ASCIIToUTF16\(google_util::AppendGoogleLocaleParam\(\s*extension_urls::AppendUtmSource\(\s*extension_urls::GetModernWebGuidanceURL\(\),\s*extension_urls::kExtensionsSidebarUtmSource\),\s*g_browser_process->GetApplicationLocale\(\)\s*\)\s*\.spec\(\)\)\);' -Replacement $guidanceReplacement -AlreadyPresent 'https://ghosium.com/support'

$hostPermissionsReplacement = "source->AddString(`"hostPermissionsLearnMoreLink`",`n                    `"https://ghosium.com/support`"));"
Replace-KnownRegex -Path $extensionsUi -Pattern '(?s)source->AddString\(\s*"hostPermissionsLearnMoreLink",\s*extension_permissions_constants::kRuntimeHostPermissionsHelpURL\s*\);' -Replacement $hostPermissionsReplacement -AlreadyPresent 'https://ghosium.com/support'

# About privacy URL for builds that expose the row.
Replace-KnownLiteral -Path $aboutPageTs -OldValue "'https://policies.google.com/privacy'" -NewValue "'https://ghosium.com/legal/privacy-policy'"

# Sweep product-owned runtime source for browser-brand support/store/project URLs
# that can escape through Settings, downloads, security warnings, accessibility,
# enterprise/help surfaces or About. This intentionally does not rewrite generic
# Google account/service URLs that represent a distinct web service rather than
# browser product branding.
$runtimeRoots = @('chrome', 'components', 'extensions', 'ui')
$textExtensions = @('.cc', '.cxx', '.h', '.hpp', '.mm', '.m', '.grd', '.grdp', '.xtb', '.html', '.htm', '.ts', '.js', '.mjs', '.json')
$urlRewrites = @(
  [pscustomobject]@{
    Pattern = 'https://support\.google\.com/(?:chrome|chromebook|chromecast)[^"''\s<>)\]]*'
    Replacement = 'https://ghosium.com/support'
  },
  [pscustomobject]@{
    Pattern = 'https://(?:chromewebstore\.google\.com|chrome\.google\.com/webstore)[^"''\s<>)\]]*'
    Replacement = 'https://store.ghosium.com/'
  },
  [pscustomobject]@{
    Pattern = 'https://(?:www\.)?google\.com/chrome[^"''\s<>)\]]*'
    Replacement = 'https://ghosium.com/'
  },
  [pscustomobject]@{
    Pattern = 'https://(?:[a-z0-9-]+\.)*chromium\.org[^"''\s<>)\]]*'
    Replacement = 'https://ghosium.com/legal/licenses'
  },
  [pscustomobject]@{
    Pattern = 'https://developer\.chrome\.com[^"''\s<>)\]]*'
    Replacement = 'https://ghosium.com/support'
  }
)

$rewrittenFiles = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($root in $runtimeRoots) {
  $absoluteRoot = Join-Path $sourceRootResolved $root
  if (!(Test-Path $absoluteRoot -PathType Container)) {
    throw "Pinned source layout changed; product-link runtime root is missing: $absoluteRoot"
  }

  foreach ($file in Get-ChildItem -Path $absoluteRoot -Recurse -File -ErrorAction Stop) {
    $relative = Get-RelativeSourcePath -FullName $file.FullName
    if ($relative -match '(^|/)(test|tests|testing|tools|third_party)(/|$)') {
      continue
    }
    if ($textExtensions -notcontains $file.Extension.ToLowerInvariant()) {
      continue
    }

    $text = [IO.File]::ReadAllText($file.FullName)
    $updated = $text

    # Handle adjacent C/C++ string literals as one URL. Consume every adjacent
    # fragment belonging to the same literal expression so a long wrapped URL
    # cannot leave a stale tail appended to the Ghosium destination.
    $updated = [regex]::Replace(
      $updated,
      'https://support\.google\.com/"(?:\s*"[^";]*")*',
      'https://ghosium.com/support"'
    )
    $updated = [regex]::Replace(
      $updated,
      'https://(?:www\.)?google\.com/"(?:\s*"[^";]*")*',
      'https://ghosium.com/"'
    )

    foreach ($rewrite in $urlRewrites) {
      $updated = [regex]::Replace(
        $updated,
        [string]$rewrite.Pattern,
        [string]$rewrite.Replacement,
        [Text.RegularExpressions.RegexOptions]::IgnoreCase
      )
    }

    if ($updated -ne $text) {
      [IO.File]::WriteAllText($file.FullName, $updated, [Text.UTF8Encoding]::new($false))
      [void]$rewrittenFiles.Add($file.FullName)
    }
  }
}

# Fail closed if any known browser-brand navigation destination remains in the
# production source after the sweep. Build-system/source-control URLs are outside
# this rule because they are not browser-generated navigation destinations.
$forbiddenBrowserUrlPatterns = @(
  'https://support\.google\.com/(?:chrome|chromebook|chromecast)',
  'https://support\.google\.com/"\s*"(?:chrome|chromebook|chromecast)',
  'https://(?:chromewebstore\.google\.com|chrome\.google\.com/webstore)',
  'https://(?:www\.)?google\.com/chrome',
  'https://(?:www\.)?google\.com/"\s*"chrome',
  'https://(?:[a-z0-9-]+\.)*chromium\.org',
  'https://developer\.chrome\.com'
)
foreach ($root in $runtimeRoots) {
  $absoluteRoot = Join-Path $sourceRootResolved $root
  foreach ($file in Get-ChildItem -Path $absoluteRoot -Recurse -File -ErrorAction Stop) {
    $relative = Get-RelativeSourcePath -FullName $file.FullName
    if ($relative -match '(^|/)(test|tests|testing|tools|third_party)(/|$)') {
      continue
    }
    if ($textExtensions -notcontains $file.Extension.ToLowerInvariant()) {
      continue
    }
    $text = [IO.File]::ReadAllText($file.FullName)
    foreach ($pattern in $forbiddenBrowserUrlPatterns) {
      if ($text -match $pattern) {
        throw "Third-party browser product URL remains in Ghosium production source: $relative ($pattern)"
      }
    }
  }
}

# Every Ghosium URL introduced into the targeted product-owned surfaces must be
# one of the exact allowlisted destinations.
$modifiedProductLinkFiles = @($urlConstants, $customizeHandler, $chromePages, $extensionsUi, $aboutPageTs)
$approved = @($config.allowedProductUrls)
foreach ($path in $modifiedProductLinkFiles) {
  $text = [IO.File]::ReadAllText($path)
  $ghosiumUrls = [regex]::Matches($text, 'https://(?:[a-z0-9-]+\.)?ghosium\.com[^"''\s<>)\]]*') |
      ForEach-Object Value | Sort-Object -Unique
  foreach ($url in $ghosiumUrls) {
    if ($approved -notcontains $url) {
      throw "Product-generated URL is outside the approved Ghosium allowlist in ${Path}: $url"
    }
  }
}

Assert-LiteralAbsent -Path $customizeHandler -Literal 'https://chromewebstore.google.com/category/themes'
Assert-LiteralAbsent -Path $aboutPageTs -Literal 'https://policies.google.com/privacy'
Assert-LiteralAbsent -Path $urlConstants -Literal 'https://support.google.com/chrome?p=help&ctx=keyboard'
Assert-LiteralAbsent -Path $urlConstants -Literal 'https://support.google.com/chrome?p=help&ctx=menu'
Assert-LiteralAbsent -Path $urlConstants -Literal 'https://support.google.com/chrome?p=help&ctx=settings'

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party status after product-link routing.'
}
if ($thirdPartyChanges) {
  throw 'Product-link routing modified third_party sources; refusing to continue.'
}

Write-Host "Ghosium first-party product link routing: OK ($($rewrittenFiles.Count) production source file(s) swept)."
