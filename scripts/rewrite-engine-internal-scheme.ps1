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
if ([string]$config.internalUi.untrustedScheme -ne 'ghost-untrusted') {
  throw 'engine/branding/product.json must define internalUi.untrustedScheme as ghost-untrusted.'
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

function Get-RelativeSourcePath {
  param([Parameter(Mandatory = $true)][string]$FullName)

  $relative = $FullName.Substring($sourceRootResolved.Length)
  $relative = $relative.TrimStart([char[]]@([char]92, [char]47))
  return ($relative -replace '\\', '/')
}

$contentUrlConstants = Join-Path $sourceRootResolved 'content/public/common/url_constants.h'
$webUiConstants = Join-Path $sourceRootResolved 'chrome/common/webui_url_constants.h'
$passwordManagerConstants = Join-Path $sourceRootResolved 'components/password_manager/content/common/web_ui_constants.h'
$profilePickerHeader = Join-Path $sourceRootResolved 'chrome/browser/ui/webui/signin/profile_picker_ui.h'
$passwordManagerHeader = Join-Path $sourceRootResolved 'chrome/browser/ui/webui/password_manager/password_manager_ui.h'
$aboutHandler = Join-Path $sourceRootResolved 'chrome/browser/browser_about_handler.cc'
foreach ($required in @(
  $contentUrlConstants,
  $webUiConstants,
  $passwordManagerConstants,
  $profilePickerHeader,
  $passwordManagerHeader,
  $aboutHandler
)) {
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
  -OldValue 'inline constexpr char kChromeUIScheme[] = "chrome";' `
  -NewValue 'inline constexpr char kChromeUIScheme[] = "ghost";'
Replace-RequiredLiteral `
  -Path $contentUrlConstants `
  -OldValue 'inline constexpr char kChromeUIUntrustedScheme[] = "chrome-untrusted";' `
  -NewValue 'inline constexpr char kChromeUIUntrustedScheme[] = "ghost-untrusted";'

# profiles/passwords are canonical native WebUI hosts, not redirects. Reuse the
# existing ProfilePickerUI and PasswordManagerUI controllers by changing only
# their central host constants. This preserves the maintained controller,
# Mojo, data-source, guest-mode and security behavior without duplicating it.
Replace-RequiredLiteral `
  -Path $webUiConstants `
  -OldValue 'inline constexpr char kChromeUIProfilePickerHost[] = "profile-picker";' `
  -NewValue 'inline constexpr char kChromeUIProfilePickerHost[] = "profiles";'
Replace-RequiredLiteral `
  -Path $webUiConstants `
  -OldValue 'inline constexpr char kChromeUIProfilePickerUrl[] = "chrome://profile-picker/";' `
  -NewValue 'inline constexpr char kChromeUIProfilePickerUrl[] = "ghost://profiles/";'
Replace-RequiredLiteral `
  -Path $passwordManagerConstants `
  -OldValue 'inline constexpr char kChromeUIPasswordManagerHost[] = "password-manager";' `
  -NewValue 'inline constexpr char kChromeUIPasswordManagerHost[] = "passwords";'

# Rewrite literal WebUI URLs used by production browser resources. In addition
# to the scheme migration, map old Profile Picker and Password Manager URL
# literals onto their canonical Ghosium hosts. Match slash/query/closing-quote
# forms so password-manager-internals and similarly named technical hosts are
# not accidentally renamed.
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
    $relative = Get-RelativeSourcePath -FullName $file.FullName
    if ($relative -match '(^|/)(test|tests|testing|tools|third_party)(/|$)') {
      continue
    }
    if ($textExtensions -notcontains $file.Extension.ToLowerInvariant()) {
      continue
    }

    $text = [IO.File]::ReadAllText($file.FullName)
    if (!$text.Contains('chrome://') -and
        !$text.Contains('chrome-untrusted://') -and
        !$text.Contains('profile-picker') -and
        !$text.Contains('password-manager')) {
      continue
    }

    $updated = $text
    $updated = $updated.Replace('chrome://profile-picker/', 'ghost://profiles/')
    $updated = $updated.Replace('chrome://profile-picker?', 'ghost://profiles?')
    $updated = $updated.Replace('chrome://profile-picker"', 'ghost://profiles"')
    $updated = $updated.Replace('chrome://password-manager/', 'ghost://passwords/')
    $updated = $updated.Replace('chrome://password-manager?', 'ghost://passwords?')
    $updated = $updated.Replace('chrome://password-manager"', 'ghost://passwords"')
    $updated = $updated.Replace('chrome-untrusted://', 'ghost-untrusted://')
    $updated = $updated.Replace('chrome://', 'ghost://')

    if ($updated -ne $text) {
      [IO.File]::WriteAllText($file.FullName, $updated, [Text.UTF8Encoding]::new($false))
      $updatedFiles++
    }
  }
}

# Confirm the canonical hosts are backed by the existing native controllers.
$profilePickerController = [IO.File]::ReadAllText($profilePickerHeader)
if (!$profilePickerController.Contains('chrome::kChromeUIProfilePickerHost')) {
  throw 'ProfilePickerUI is no longer registered through kChromeUIProfilePickerHost; review ghost://profiles integration.'
}
$passwordManagerController = [IO.File]::ReadAllText($passwordManagerHeader)
if (!$passwordManagerController.Contains('password_manager::kChromeUIPasswordManagerHost')) {
  throw 'PasswordManagerUI is no longer registered through kChromeUIPasswordManagerHost; review ghost://passwords integration.'
}

$webUiText = [IO.File]::ReadAllText($webUiConstants)
$passwordConstantsText = [IO.File]::ReadAllText($passwordManagerConstants)
if (!$webUiText.Contains('kChromeUIProfilePickerHost[] = "profiles"')) {
  throw 'Native Profile Picker host did not become ghost://profiles.'
}
if (!$webUiText.Contains('kChromeUIProfilePickerUrl[] = "ghost://profiles/"')) {
  throw 'Native Profile Picker URL did not become ghost://profiles/.'
}
if (!$passwordConstantsText.Contains('kChromeUIPasswordManagerHost[] = "passwords"')) {
  throw 'Native Password Manager host did not become ghost://passwords.'
}
foreach ($passwordRoute in @(
  'ghost://passwords/checkup?start=true',
  'ghost://passwords/settings',
  'ghost://passwords'
)) {
  if (!$webUiText.Contains($passwordRoute)) {
    throw "Password Manager URL constant did not become canonical: $passwordRoute"
  }
}

# There must be no browser_about_handler redirect shim for the two canonical
# hosts. The typed URL is itself the native controller URL.
$aboutText = [IO.File]::ReadAllText($aboutHandler)
foreach ($forbiddenAlias in @(
  'host == "profiles"',
  'GURL("ghost://settings/manageProfile")',
  'host == "passwords"',
  'GURL("ghost://password-manager/")'
)) {
  if ($aboutText.Contains($forbiddenAlias)) {
    throw "Redirect alias remains for canonical Ghosium WebUI host: $forbiddenAlias"
  }
}

# Canonical product routes. All eight now resolve through native WebUI host
# registrations rather than browser_about_handler aliases.
$requiredNativeRoutes = @(
  'ghost://newtab/',
  'ghost://history/',
  'ghost://bookmarks/',
  'ghost://downloads/',
  'ghost://settings/',
  'ghost://profiles/',
  'ghost://extensions/',
  'ghost://passwords/'
)
$nativeRouteEvidence = $webUiText + "`n" + $passwordConstantsText
foreach ($route in $requiredNativeRoutes) {
  if (!$nativeRouteEvidence.Contains($route)) {
    throw "Required native Ghosium internal route was not produced: $route"
  }
}

# Production source must not retain the old trusted/untrusted scheme or the two
# superseded product hosts. Technical symbol/path names may remain where they
# are source API, but URL literals must be canonical.
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
    if ($text.Contains('chrome://') -or $text.Contains('chrome-untrusted://')) {
      throw "Legacy internal WebUI scheme remains in production source: $relative"
    }
    if ($text.Contains('ghost://profile-picker/') -or
        $text.Contains('ghost://profile-picker?') -or
        $text.Contains('ghost://password-manager/') -or
        $text.Contains('ghost://password-manager?')) {
      throw "Superseded Ghosium product WebUI host remains in production source: $relative"
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

Write-Host "Ghosium ghost:// routing applied with native profiles/passwords hosts; updated $updatedFiles production source file(s)."
