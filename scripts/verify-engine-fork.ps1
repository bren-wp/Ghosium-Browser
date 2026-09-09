param(
  [Parameter(Mandatory = $false)]
  [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $repoRoot 'engine/branding/product.json'
$productVersionPath = Join-Path $repoRoot 'VERSION'
$sourceRevisionPath = Join-Path $repoRoot 'ENGINE_SOURCE_REVISION'
$snapshotRevisionPath = Join-Path $repoRoot 'ENGINE_REVISION'
$thirdPartyNoticesPath = Join-Path $repoRoot 'THIRD_PARTY_NOTICES.md'
$brandSvgPath = Join-Path $repoRoot 'engine/branding/ghosium-mark.svg'
$brandDarkSvgPath = Join-Path $repoRoot 'engine/branding/ghosium-mark-dark.svg'
$productVectorPath = Join-Path $repoRoot 'engine/branding/vector/product.icon'
$productRefreshVectorPath = Join-Path $repoRoot 'engine/branding/vector/product_refresh.icon'
$assetGeneratorPath = Join-Path $repoRoot 'scripts/generate-engine-brand-assets.py'
$defaultSearchRewritePath = Join-Path $repoRoot 'scripts/rewrite-engine-default-search.ps1'
$windowsIdentityRewritePath = Join-Path $repoRoot 'scripts/rewrite-engine-windows-identity.ps1'
$productVersionRewritePath = Join-Path $repoRoot 'scripts/rewrite-engine-product-version.ps1'
$internalSchemeRewritePath = Join-Path $repoRoot 'scripts/rewrite-engine-internal-scheme.ps1'
$publicSurfacesRewritePath = Join-Path $repoRoot 'scripts/rewrite-engine-public-surfaces.ps1'
$performanceDefaultsRewritePath = Join-Path $repoRoot 'scripts/rewrite-engine-performance-defaults.ps1'

foreach ($required in @(
  $configPath,
  $productVersionPath,
  $sourceRevisionPath,
  $snapshotRevisionPath,
  $thirdPartyNoticesPath,
  $brandSvgPath,
  $brandDarkSvgPath,
  $productVectorPath,
  $productRefreshVectorPath,
  $assetGeneratorPath,
  $defaultSearchRewritePath,
  $windowsIdentityRewritePath,
  $productVersionRewritePath,
  $internalSchemeRewritePath,
  $publicSurfacesRewritePath,
  $performanceDefaultsRewritePath
)) {
  if (!(Test-Path $required -PathType Leaf)) {
    throw "Required Ghosium fork file is missing: $required"
  }
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$productVersion = (Get-Content $productVersionPath -Raw).Trim()
$sourceRevision = (Get-Content $sourceRevisionPath -Raw).Trim()
$snapshotRevision = (Get-Content $snapshotRevisionPath -Raw).Trim()

if ($productVersion -notmatch '^0\.\d+\.\d+$') {
  throw "Ghosium VERSION must use the 0.x.y product line; found '$productVersion'."
}
if ($sourceRevision -notmatch '^[0-9a-f]{40}$') {
  throw 'ENGINE_SOURCE_REVISION must be a pinned 40-character lowercase Git commit.'
}
if ($snapshotRevision -notmatch '^\d+$') {
  throw 'ENGINE_REVISION must remain a pinned numeric snapshot revision.'
}
if ($config.source.commit -ne $sourceRevision) {
  throw 'engine/branding/product.json source.commit does not match ENGINE_SOURCE_REVISION.'
}
if ([string]$config.source.snapshotRevision -ne $snapshotRevision) {
  throw 'engine/branding/product.json source.snapshotRevision does not match ENGINE_REVISION.'
}

if ($config.product.name -ne 'Ghosium Browser' -or $config.product.shortName -ne 'Ghosium') {
  throw 'Product branding contract must use Ghosium Browser / Ghosium.'
}
if ($config.product.publisher -ne 'Brendigo' -or $config.product.windowsCompanyName -ne 'Brendigo') {
  throw 'Publisher metadata must remain Brendigo.'
}

$expectedUrls = @(
  'https://ghosium.com/',
  'https://store.ghosium.com/',
  'https://ghosium.com/legal/terms',
  'https://ghosium.com/legal/privacy-policy',
  'https://ghosium.com/legal/licenses',
  'https://ghosium.com/support',
  'https://ghosium.com/security'
)
$actualUrls = @($config.allowedProductUrls)
if ($actualUrls.Count -ne $expectedUrls.Count) {
  throw "Ghosium product URL allowlist must contain exactly $($expectedUrls.Count) entries."
}
if (@($actualUrls | Sort-Object -Unique).Count -ne $actualUrls.Count) {
  throw 'Ghosium product URL allowlist contains duplicate entries.'
}
foreach ($url in $expectedUrls) {
  if ($actualUrls -notcontains $url) {
    throw "Missing required Ghosium product URL: $url"
  }
}
foreach ($property in $config.productUrls.PSObject.Properties) {
  if ($actualUrls -notcontains [string]$property.Value) {
    throw "Product-generated URL is outside the approved allowlist: $($property.Value)"
  }
}

$expectedInternalRoutes = @(
  'ghost://newtab/',
  'ghost://history/',
  'ghost://bookmarks/',
  'ghost://downloads/',
  'ghost://settings/',
  'ghost://profiles/',
  'ghost://extensions/',
  'ghost://passwords/'
)
if ([string]$config.internalUi.scheme -ne 'ghost' -or
    [string]$config.internalUi.untrustedScheme -ne 'ghost-untrusted') {
  throw 'Ghosium internal UI must use ghost:// and ghost-untrusted://.'
}
$actualInternalRoutes = @($config.internalUi.routes)
if ($actualInternalRoutes.Count -ne $expectedInternalRoutes.Count -or
    @($actualInternalRoutes | Sort-Object -Unique).Count -ne $expectedInternalRoutes.Count) {
  throw 'Ghosium internal UI route contract must contain exactly eight unique routes.'
}
foreach ($route in $expectedInternalRoutes) {
  if ($actualInternalRoutes -notcontains $route) {
    throw "Missing required Ghosium internal UI route: $route"
  }
}

$locales = @($config.locales.supported)
if ($locales.Count -ne 38) {
  throw "Ghosium must define exactly 38 supported locales; found $($locales.Count)."
}
if (@($locales | Sort-Object -Unique).Count -ne 38) {
  throw 'Ghosium locale list contains duplicates.'
}
if ($config.locales.default -ne 'en-US') {
  throw 'English en-US must remain the default locale.'
}
if ($config.locales.required -ne 'hr' -or $locales -notcontains 'hr') {
  throw 'Croatian hr must remain a required supported locale.'
}
if ($locales -notcontains 'en-US') {
  throw 'The supported locale set must contain en-US.'
}

if (!$config.legal.preserveThirdPartyLicenses -or !$config.legal.preserveCopyrightNotices -or !$config.legal.preserveAttribution) {
  throw 'Third-party legal preservation invariants must remain enabled.'
}
if ([string]$config.legal.thirdPartySurface -ne 'legal/third-party') {
  throw 'Third-party attribution must remain isolated under legal/third-party.'
}

foreach ($securityInvariant in @('sandbox', 'processIsolation', 'certificateValidation', 'extensionSignatureVerification', 'updateSignatureVerification')) {
  if ([string]$config.securityInvariants.$securityInvariant -ne 'required') {
    throw "Security invariant must remain required: $securityInvariant"
  }
}

function Assert-NoLegacyVisibleBrand {
  param(
    [Parameter(Mandatory = $true)][string]$Path
  )

  $text = Get-Content $Path -Raw
  $messages = [regex]::Matches($text, '(?s)<message\b[^>]*>(.*?)</message>')
  foreach ($message in $messages) {
    $visible = [regex]::Replace($message.Groups[1].Value, '<[^>]+>', '')
    $visible = [System.Net.WebUtility]::HtmlDecode($visible)
    if ($visible -match '(?i)\bChromium\b|\bGoogle Chrome\b|\bChrome\b') {
      throw "Legacy browser branding remains in a user-visible GRIT message in $Path"
    }
  }
}

function Assert-FilePrefix {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][byte[]]$Prefix
  )

  if (!(Test-Path $Path -PathType Leaf)) {
    throw "Expected generated Ghosium asset is missing: $Path"
  }
  $bytes = [IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -lt $Prefix.Length) {
    throw "Generated Ghosium asset is unexpectedly small: $Path"
  }
  for ($i = 0; $i -lt $Prefix.Length; $i++) {
    if ($bytes[$i] -ne $Prefix[$i]) {
      throw "Generated Ghosium asset has an invalid file signature: $Path"
    }
  }
}

if ($SourceRoot) {
  $resolvedSourceRoot = (Resolve-Path $SourceRoot).Path
  $gitDirectory = Join-Path $resolvedSourceRoot '.git'
  if (!(Test-Path $gitDirectory)) {
    throw "SourceRoot is not a Git checkout: $resolvedSourceRoot"
  }

  $actualCommit = (& git -C $resolvedSourceRoot rev-parse HEAD).Trim()
  if ($LASTEXITCODE -ne 0 -or $actualCommit -ne $sourceRevision) {
    throw "Engine checkout must be detached at $sourceRevision; found $actualCommit"
  }

  $requiredEngineFiles = @(
    'chrome/app/chromium_strings.grd',
    'chrome/app/settings_chromium_strings.grdp',
    'chrome/common/url_constants.h',
    'chrome/common/webui_url_constants.h',
    'chrome/common/ghosium_product_version.h',
    'components/password_manager/content/common/web_ui_constants.h',
    'content/public/common/url_constants.h',
    'chrome/browser/browser_about_handler.cc',
    'chrome/browser/ui/webui/version/version_ui.cc',
    'chrome/browser/ui/webui/signin/profile_picker_ui.h',
    'chrome/browser/ui/webui/password_manager/password_manager_ui.h',
    'chrome/app/theme/chromium/BRANDING',
    'chrome/app/theme/chromium/product_logo.svg',
    'chrome/install_static/chromium_install_modes.h',
    'chrome/installer/setup/setup_main.cc',
    'chrome/installer/setup/uninstall.cc',
    'chrome/installer/setup/install_worker.cc',
    'chrome/installer/util/util_constants.h',
    'chrome/browser/resources/contextual_tasks/top_toolbar_logo.html.ts',
    'chrome/browser/resources/signin/managed_user_profile_notice/managed_user_profile_notice_value_prop.html.ts',
    'ui/webui/resources/images/chrome_logo_dark.svg',
    'components/search_engines/template_url_prepopulate_data.cc',
    'components/vector_icons/chromium/product.icon',
    'components/vector_icons/chromium/product_refresh.icon',
    'extensions/strings/extensions_chromium_strings.grdp'
  )
  foreach ($relativePath in $requiredEngineFiles) {
    if (!(Test-Path (Join-Path $resolvedSourceRoot $relativePath) -PathType Leaf)) {
      throw "Pinned engine source is missing expected file: $relativePath"
    }
  }

  $productStringsPath = Join-Path $resolvedSourceRoot 'chrome/app/chromium_strings.grd'
  $settingsStringsPath = Join-Path $resolvedSourceRoot 'chrome/app/settings_chromium_strings.grdp'
  $productStrings = Get-Content $productStringsPath -Raw
  foreach ($needle in @('Ghosium Browser', 'Ghosium')) {
    if (!$productStrings.Contains($needle)) {
      throw "Applied engine branding is missing expected product string: $needle"
    }
  }
  if (!$productStrings.Contains('Customize Ghosium')) {
    throw 'Customize side-panel title is not Ghosium branded.'
  }
  Assert-NoLegacyVisibleBrand -Path $productStringsPath
  Assert-NoLegacyVisibleBrand -Path $settingsStringsPath
  Assert-NoLegacyVisibleBrand -Path (Join-Path $resolvedSourceRoot 'extensions/strings/extensions_chromium_strings.grdp')

  $settingsStrings = Get-Content $settingsStringsPath -Raw
  if (!$settingsStrings.Contains('About Ghosium Browser')) {
    throw 'About surface is not Ghosium branded.'
  }
  if (!$settingsStrings.Contains('Ghosium Support')) {
    throw 'Settings help surface is not routed as Ghosium Support.'
  }

  $versionHeader = Get-Content (Join-Path $resolvedSourceRoot 'chrome/common/ghosium_product_version.h') -Raw
  if (!$versionHeader.Contains("kProductVersion[] = `"$productVersion`"")) {
    throw "Generated Ghosium product version header does not match VERSION $productVersion."
  }
  $versionUi = Get-Content (Join-Path $resolvedSourceRoot 'chrome/browser/ui/webui/version/version_ui.cc') -Raw
  foreach ($requiredVersionUi in @(
    '#include "chrome/common/ghosium_product_version.h"',
    'ghosium::kProductVersion',
    'base::UTF8ToUTF16(ghosium::kProductVersion)'
  )) {
    if (!$versionUi.Contains($requiredVersionUi)) {
      throw "Ghosium About/version surface is missing product-version integration: $requiredVersionUi"
    }
  }
  if ($versionUi -match 'html_source->AddString\(version_ui::kVersion,\s*version_info::GetVersionNumber\(\)\);' -or
      $versionUi.Contains('base::UTF8ToUTF16(version_info::GetVersionNumber()),')) {
    throw 'Public Ghosium About/version surfaces still display the engine compatibility version as the product version.'
  }

  $branding = Get-Content (Join-Path $resolvedSourceRoot 'chrome/app/theme/chromium/BRANDING') -Raw
  foreach ($requiredBrandingLine in @(
    'COMPANY_FULLNAME=Brendigo',
    'COMPANY_SHORTNAME=Brendigo',
    'PRODUCT_FULLNAME=Ghosium Browser',
    'PRODUCT_SHORTNAME=Ghosium',
    'PRODUCT_INSTALLER_FULLNAME=Ghosium Browser Installer',
    'PRODUCT_INSTALLER_SHORTNAME=Ghosium Installer',
    'MAC_BUNDLE_ID=com.brendigo.ghosium'
  )) {
    if (!$branding.Contains($requiredBrandingLine)) {
      throw "Engine BRANDING is missing required identity: $requiredBrandingLine"
    }
  }

  $urlConstants = Get-Content (Join-Path $resolvedSourceRoot 'chrome/common/url_constants.h') -Raw
  if (!$urlConstants.Contains('https://ghosium.com/support')) {
    throw 'Engine product URL routing is missing Ghosium Support.'
  }
  if ($urlConstants.Contains('https://support.google.com/chrome?p=help&ctx=')) {
    throw 'Legacy third-party Help URLs remain in Ghosium product routing.'
  }

  $contentUrlConstants = Get-Content (Join-Path $resolvedSourceRoot 'content/public/common/url_constants.h') -Raw
  if (!$contentUrlConstants.Contains('kChromeUIScheme[] = "ghost"') -or
      !$contentUrlConstants.Contains('kChromeUIUntrustedScheme[] = "ghost-untrusted"')) {
    throw 'Canonical Ghosium WebUI schemes are not ghost / ghost-untrusted.'
  }
  if ($contentUrlConstants.Contains('kChromeUIScheme[] = "chrome"') -or
      $contentUrlConstants.Contains('kChromeUIUntrustedScheme[] = "chrome-untrusted"')) {
    throw 'Legacy internal WebUI scheme values remain active.'
  }

  $webUiConstants = Get-Content (Join-Path $resolvedSourceRoot 'chrome/common/webui_url_constants.h') -Raw
  foreach ($nativeRoute in @(
    'ghost://newtab/',
    'ghost://history/',
    'ghost://bookmarks/',
    'ghost://downloads/',
    'ghost://settings/',
    'ghost://profiles/',
    'ghost://extensions/'
  )) {
    if (!$webUiConstants.Contains($nativeRoute)) {
      throw "Ghosium WebUI constants are missing: $nativeRoute"
    }
  }

  $passwordConstants = Get-Content (Join-Path $resolvedSourceRoot 'components/password_manager/content/common/web_ui_constants.h') -Raw
  $profilePickerController = Get-Content (Join-Path $resolvedSourceRoot 'chrome/browser/ui/webui/signin/profile_picker_ui.h') -Raw
  $passwordManagerController = Get-Content (Join-Path $resolvedSourceRoot 'chrome/browser/ui/webui/password_manager/password_manager_ui.h') -Raw
  if (!$webUiConstants.Contains('kChromeUIProfilePickerHost[] = "profiles"') -or
      !$webUiConstants.Contains('kChromeUIProfilePickerUrl[] = "ghost://profiles/"') -or
      !$profilePickerController.Contains('chrome::kChromeUIProfilePickerHost')) {
    throw 'ghost://profiles is not backed by the native ProfilePickerUI host contract.'
  }
  if (!$passwordConstants.Contains('kChromeUIPasswordManagerHost[] = "passwords"') -or
      !$passwordManagerController.Contains('password_manager::kChromeUIPasswordManagerHost') -or
      !$webUiConstants.Contains('ghost://passwords/checkup?start=true') -or
      !$webUiConstants.Contains('ghost://passwords/settings') -or
      !$webUiConstants.Contains('ghost://passwords')) {
    throw 'ghost://passwords is not backed by the native PasswordManagerUI host contract.'
  }
  if ($webUiConstants.Contains('ghost://profile-picker/') -or
      $webUiConstants.Contains('ghost://password-manager/')) {
    throw 'Superseded profile-picker/password-manager product URLs remain active.'
  }

  $aboutHandler = Get-Content (Join-Path $resolvedSourceRoot 'chrome/browser/browser_about_handler.cc') -Raw
  foreach ($forbiddenAlias in @(
    'host == "profiles"',
    'GURL("ghost://settings/manageProfile")',
    'host == "passwords"',
    'GURL("ghost://password-manager/")'
  )) {
    if ($aboutHandler.Contains($forbiddenAlias)) {
      throw "Canonical ghost://profiles/passwords regressed to a browser_about_handler alias: $forbiddenAlias"
    }
  }

  $searchSource = Get-Content (Join-Path $resolvedSourceRoot 'components/search_engines/template_url_prepopulate_data.cc') -Raw
  foreach ($requiredGoogleFallback in @(
    'return FindPrepopulatedEngineInternal(prefs, regional_prepopulated_engines,',
    'google.id,',
    '/*use_first_as_fallback=*/true'
  )) {
    if (!$searchSource.Contains($requiredGoogleFallback)) {
      throw "Google Search fallback integration is missing: $requiredGoogleFallback"
    }
  }
  foreach ($forbiddenSearchIdentity in @(
    'Ghosium Search',
    'search.ghosium.com',
    'prepopulate_id = 1101',
    '9e993bd9-c256-42d7-a1b1-000000001101'
  )) {
    if ($searchSource.Contains($forbiddenSearchIdentity)) {
      throw "Retired Ghosium Search integration remains in engine source: $forbiddenSearchIdentity"
    }
  }

  $windowsIdentity = Get-Content (Join-Path $resolvedSourceRoot 'chrome/install_static/chromium_install_modes.h') -Raw
  foreach ($requiredWindowsIdentity in @(
    'kCompanyPathName[] = L"Brendigo"',
    'kProductPathName[] = L"Ghosium"',
    '.base_app_name = L"Ghosium Browser"',
    '.base_app_id = L"Ghosium"',
    '.browser_prog_id_prefix = L"GhosiumHTM"',
    'L"Ghosium HTML Document"',
    '.direct_launch_url_scheme = "ghosium"',
    '.pdf_prog_id_prefix = L"GhosiumPDF"',
    'L"Ghosium PDF Document"'
  )) {
    if (!$windowsIdentity.Contains($requiredWindowsIdentity)) {
      throw "Ghosium Windows install identity is missing: $requiredWindowsIdentity"
    }
  }
  foreach ($legacyWindowsIdentity in @(
    'kProductPathName[] = L"Chromium"',
    '.base_app_name = L"Chromium"',
    '.base_app_id = L"Chromium"',
    '.browser_prog_id_prefix = L"ChromiumHTM"',
    'L"Chromium HTML Document"',
    '.direct_launch_url_scheme = "chromium"',
    '.pdf_prog_id_prefix = L"ChromiumPDF"',
    'L"Chromium PDF Document"'
  )) {
    if ($windowsIdentity.Contains($legacyWindowsIdentity)) {
      throw "Legacy Windows product identity remains active: $legacyWindowsIdentity"
    }
  }
  if (!$windowsIdentity.Contains('kSafeBrowsingName[] = "chromium"')) {
    throw 'Safe Browsing client identity changed unexpectedly; security integration requires explicit review.'
  }

  $setupMain = Get-Content (Join-Path $resolvedSourceRoot 'chrome/installer/setup/setup_main.cc') -Raw
  $uninstallSource = Get-Content (Join-Path $resolvedSourceRoot 'chrome/installer/setup/uninstall.cc') -Raw
  $installWorker = Get-Content (Join-Path $resolvedSourceRoot 'chrome/installer/setup/install_worker.cc') -Raw
  $utilConstants = Get-Content (Join-Path $resolvedSourceRoot 'chrome/installer/util/util_constants.h') -Raw
  if (!$setupMain.Contains('HasSwitch(installer::switches::kUninstall)') -or !$setupMain.Contains('UninstallProduct(')) {
    throw 'Ghosium setup-based uninstall dispatch is not intact.'
  }
  if (!$uninstallSource.Contains('InstallStatus UninstallProduct(')) {
    throw 'Ghosium source is missing the normal installer uninstall implementation.'
  }
  if (!$utilConstants.Contains('kSetupExe[] = L"setup.exe"') -or
      !$utilConstants.Contains('kUninstallStringField[] = L"UninstallString"') -or
      !$utilConstants.Contains('kUninstallArgumentsField[] = L"UninstallArguments"')) {
    throw 'Ghosium setup-based uninstall registry constants changed unexpectedly.'
  }
  if (!$installWorker.Contains('installer::kUninstallStringField') -or
      !$installWorker.Contains('installer::kUninstallArgumentsField')) {
    throw 'Ghosium installer no longer registers the setup-based uninstall command.'
  }

  $productSvg = Get-Content (Join-Path $resolvedSourceRoot 'chrome/app/theme/chromium/product_logo.svg') -Raw
  if (!$productSvg.Contains('aria-label="Ghosium"') -or !$productSvg.Contains('#62E7D5')) {
    throw 'Product logo SVG was not replaced with the Ghosium mark.'
  }

  $darkLogo = Get-Content (Join-Path $resolvedSourceRoot 'ui/webui/resources/images/chrome_logo_dark.svg') -Raw
  if (!$darkLogo.Contains('aria-label="Ghosium"') -or !$darkLogo.Contains('#62E7D5')) {
    throw 'Shared dark-mode WebUI product logo was not replaced with Ghosium.'
  }

  $contextualToolbar = Get-Content (Join-Path $resolvedSourceRoot 'chrome/browser/resources/contextual_tasks/top_toolbar_logo.html.ts') -Raw
  if ($contextualToolbar.Contains('chrome_product.svg') -or $contextualToolbar.Contains('chrome_logo_dark.svg')) {
    throw 'Contextual toolbar still references a legacy product logo asset.'
  }
  if ([regex]::Matches($contextualToolbar, 'ghost://theme/current-channel-logo@2x').Count -lt 2) {
    throw 'Contextual toolbar is not consistently routed through the Ghosium internal scheme.'
  }
  if ($contextualToolbar.Contains('chrome://')) {
    throw 'Contextual toolbar still exposes the legacy internal WebUI scheme.'
  }

  $managedProfile = Get-Content (Join-Path $resolvedSourceRoot 'chrome/browser/resources/signin/managed_user_profile_notice/managed_user_profile_notice_value_prop.html.ts') -Raw
  if (!$managedProfile.Contains('alt="Ghosium logo"') -or $managedProfile.Contains('alt="Chrome logo"')) {
    throw 'Managed-profile product-logo accessibility text is not Ghosium branded.'
  }

  $productVector = Get-Content (Join-Path $resolvedSourceRoot 'components/vector_icons/chromium/product.icon') -Raw
  $productRefreshVector = Get-Content (Join-Path $resolvedSourceRoot 'components/vector_icons/chromium/product_refresh.icon') -Raw
  if (!$productVector.Contains('Ghosium product vector mark') -or !$productRefreshVector.Contains('Ghosium product vector mark')) {
    throw 'Product vector icons were not replaced with Ghosium vectors.'
  }

  $pngSignature = [byte[]](0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
  foreach ($relativePng in @(
    'chrome/app/theme/chromium/product_logo_16.png',
    'chrome/app/theme/chromium/product_logo_24.png',
    'chrome/app/theme/chromium/product_logo_32.png',
    'chrome/app/theme/chromium/product_logo_48.png',
    'chrome/app/theme/chromium/product_logo_64.png',
    'chrome/app/theme/chromium/product_logo_128.png',
    'chrome/app/theme/default_100_percent/chromium/product_logo_16.png',
    'chrome/app/theme/default_100_percent/chromium/product_logo_32.png',
    'chrome/app/theme/default_200_percent/chromium/product_logo_16.png',
    'chrome/app/theme/default_200_percent/chromium/product_logo_32.png',
    'chrome/app/theme/chromium/win/tiles/Logo.png',
    'chrome/app/theme/chromium/win/tiles/SmallLogo.png'
  )) {
    Assert-FilePrefix -Path (Join-Path $resolvedSourceRoot $relativePng) -Prefix $pngSignature
  }

  $icoSignature = [byte[]](0x00, 0x00, 0x01, 0x00)
  foreach ($relativeIco in @(
    'chrome/app/theme/chromium/win/chromium.ico',
    'chrome/app/theme/chromium/win/chromium_doc.ico',
    'chrome/app/theme/chromium/win/chromium_pdf.ico',
    'chrome/app/theme/chromium/win/app_list.ico',
    'chrome/app/theme/chromium/win/incognito.ico',
    'chrome/app/theme/chromium/win/isolated.ico'
  )) {
    Assert-FilePrefix -Path (Join-Path $resolvedSourceRoot $relativeIco) -Prefix $icoSignature
  }

  $status = & git -C $resolvedSourceRoot status --porcelain=v1 -- third_party
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to verify third_party source status.'
  }
  if ($status) {
    throw 'Ghosium branding automation must not modify third_party sources.'
  }
}

Write-Host 'Ghosium full-source engine fork contract: OK'
