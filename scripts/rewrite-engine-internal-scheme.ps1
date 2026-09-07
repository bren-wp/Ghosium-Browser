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
  throw "Refusing to rewrite internal UI routing in an unpinned checkout. Expected $expectedCommit; found $actualCommit"
}

if ([string]$config.internalUi.scheme -ne 'ghost') {
  throw 'engine/branding/product.json must define internalUi.scheme as ghost.'
}

function Replace-RequiredLiteral {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$OldValue,
    [Parameter(Mandatory = $true)][string]$NewValue
  )

  $text = [IO.File]::ReadAllText($Path)
  if ($text.Contains($OldValue)) {
    [IO.File]::WriteAllText(
      $Path,
      $text.Replace($OldValue, $NewValue),
      [Text.UTF8Encoding]::new($false)
    )
    return
  }
  if (!$text.Contains($NewValue)) {
    throw "Neither expected old nor Ghosium internal-UI literal was found in ${Path}: $OldValue"
  }
}

$contentUrlConstants = Join-Path $sourceRootResolved 'content/public/common/url_constants.h'
$webUiConstants = Join-Path $sourceRootResolved 'chrome/common/webui_url_constants.h'
$aboutHandler = Join-Path $sourceRootResolved 'chrome/browser/browser_about_handler.cc'
foreach ($required in @($contentUrlConstants, $webUiConstants, $aboutHandler)) {
  if (!(Test-Path $required -PathType Leaf)) {
    throw "Pinned source layout changed; internal UI target is missing: $required"
  }
}

# Make ghost:// the canonical trusted WebUI scheme and keep the untrusted
# companion namespace branded consistently. C++ symbol names are intentionally
# left intact because they are upstream ABI/source identifiers rather than
# user-facing product branding.
Replace-RequiredLiteral `
  -Path $contentUrlConstants `
  -OldValue 'inline constexpr char kChromeUIScheme[] = "chrome"; // Used for WebUIs.' `
  -NewValue 'inline constexpr char kChromeUIScheme[] = "ghost"; // Used for Ghosium WebUIs.'
Replace-RequiredLiteral `
  -Path $contentUrlConstants `
  -OldValue 'inline constexpr char kChromeUIUntrustedScheme[] = "chrome-untrusted";' `
  -NewValue 'inline constexpr char kChromeUIUntrustedScheme[] = "ghost-untrusted";'

# Rewrite literal WebUI URLs used by production browser resources. This must be
# broad enough that ghost:// pages do not depend on stale chrome://resource URLs
# after the canonical scheme changes. Tests, tooling and third_party are not
# production runtime inputs and are deliberately excluded.
$runtimeRoots = @('chrome', 'components', 'content', 'extensions', 'ui')
$textExtensions = @(
  '.cc', '.cxx', '.h', '.hpp', '.mm', '.m',
  '.grd', '.grdp', '.xtb', '.html', '.htm',
  '.ts', '.js', '.mjs', '.json', '.css', '.mojom'
)
$updatedFiles = 0
foreach ($root in $runtimeRoots) {
  $absoluteRoot = Join-Path $sourceRootResolved $root
  if (!(Test-Path $absoluteRoot -PathType Container)) {
    throw "Pinned source layout changed; runtime root is missing: $absoluteRoot"
  }

  foreach ($file in Get-ChildItem -Path $absoluteRoot -Recurse -File -ErrorAction Stop) {
    $relative = $file.FullName.Substring($sourceRootResolved.Length).TrimStart('\', '/') -replace '\\', '/'
    if ($relative -match '(^|/)(test|tests|testing|tools|third_party)(/|$)') {
      continue
    }
    if ($textExtensions -notcontains $file.Extension.ToLowerInvariant()) {
      continue
    }

    $text = [IO.File]::ReadAllText($file.FullName)
    if (!$text.Contains('chrome://') -and !$text.Contains('chrome-untrusted://')) {
      continue
    }

    $updated = $text.Replace('chrome-untrusted://', 'ghost-untrusted://')
    $updated = $updated.Replace('chrome://', 'ghost://')
    if ($updated -ne $text) {
      [IO.File]::WriteAllText($file.FullName, $updated, [Text.UTF8Encoding]::new($false))
      $updatedFiles++
    }
  }
}

# The requested public aliases map onto the existing, maintained WebUI
# controllers instead of duplicating password/profile implementations.
$aboutText = [IO.File]::ReadAllText($aboutHandler)
$aliasAnchor = @'
  if (host == chrome::kChromeUIAboutHost) {
    // Replace ghost://about with ghost://chrome-urls.
    host = chrome::kChromeUIChromeURLsHost;
  }
'@
$aliasReplacement = @'
  if (host == chrome::kChromeUIAboutHost) {
    // Replace ghost://about with the internal URL directory.
    host = chrome::kChromeUIChromeURLsHost;
  }

  if (host == "profiles") {
    *url = GURL("ghost://settings/manageProfile");
    return false;
  }

  if (host == "passwords") {
    *url = GURL("ghost://password-manager/");
    return false;
  }
'@
if ($aboutText.Contains($aliasAnchor)) {
  $aboutText = $aboutText.Replace($aliasAnchor, $aliasReplacement)
  [IO.File]::WriteAllText($aboutHandler, $aboutText, [Text.UTF8Encoding]::new($false))
} elseif (!$aboutText.Contains('GURL("ghost://settings/manageProfile")') -or
          !$aboutText.Contains('GURL("ghost://password-manager/")')) {
  throw 'Unable to install ghost://profiles and ghost://passwords aliases; browser_about_handler.cc layout changed.'
}

# Canonical routes requested by the product contract. Six hosts are native
# WebUIs; profiles/passwords are aliases installed above.
$webUiText = [IO.File]::ReadAllText($webUiConstants)
$requiredNativeRoutes = @(
  'ghost://newtab/',
  'ghost://history/',
  'ghost://bookmarks/',
  'ghost://downloads/',
  'ghost://settings/',
  'ghost://extensions/'
)
foreach ($route in $requiredNativeRoutes) {
  if (!$webUiText.Contains($route)) {
    throw "Required Ghosium internal route was not produced: $route"
  }
}

foreach ($root in $runtimeRoots) {
  $absoluteRoot = Join-Path $sourceRootResolved $root
  foreach ($file in Get-ChildItem -Path $absoluteRoot -Recurse -File -ErrorAction Stop) {
    $relative = $file.FullName.Substring($sourceRootResolved.Length).TrimStart('\', '/') -replace '\\', '/'
    if ($relative -match '(^|/)(test|tests|testing|tools|third_party)(/|$)') {
      continue
    }
    if ($textExtensions -notcontains $file.Extension.ToLowerInvariant()) {
      continue
    }
    $text = [IO.File]::ReadAllText($file.FullName)
    if ($text.Contains('chrome://') -or $text.Contains('chrome-untrusted://')) {
      throw "Legacy internal WebUI scheme remains in production source: $relative"
    }
  }
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party source status after internal UI rebranding.'
}
if ($thirdPartyChanges) {
  throw 'Internal UI rebranding modified third_party sources; refusing to continue.'
}

Write-Host "Ghosium ghost:// internal UI routing applied; updated $updatedFiles production source file(s)."
