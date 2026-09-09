param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedRevision = (Get-Content (Join-Path $repoRoot 'ENGINE_SOURCE_REVISION') -Raw).Trim()
$brandSvg = Join-Path $repoRoot 'engine/branding/ghosium-mark.svg'
$sourceRootResolved = (Resolve-Path $SourceRoot).Path

if (!(Test-Path (Join-Path $sourceRootResolved '.git'))) {
  throw "SourceRoot is not a Git checkout: $sourceRootResolved"
}
$actualRevision = (& git -C $sourceRootResolved rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualRevision -ne $expectedRevision) {
  throw "Native New Tab hardening requires pinned source $expectedRevision; found $actualRevision"
}

$uiPath = Join-Path $sourceRootResolved 'chrome/browser/ui/webui/new_tab_page/new_tab_page_ui.cc'
$logoTsPath = Join-Path $sourceRootResolved 'chrome/browser/resources/new_tab_page/logo.ts'
$logoCssPath = Join-Path $sourceRootResolved 'chrome/browser/resources/new_tab_page/logo.css'
$logoAssetPath = Join-Path $sourceRootResolved 'chrome/browser/resources/new_tab_page/icons/google_logo.svg'
foreach ($path in @($uiPath, $logoTsPath, $logoCssPath, $logoAssetPath, $brandSvg)) {
  if (!(Test-Path $path -PathType Leaf)) {
    throw "Required native New Tab input is missing: $path"
  }
}

function Replace-RequiredPattern {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string]$Replacement,
    [int]$ExpectedCount = 1
  )
  $text = [IO.File]::ReadAllText($Path)
  $regex = [regex]::new($Pattern, [Text.RegularExpressions.RegexOptions]::Singleline)
  $count = $regex.Matches($text).Count
  if ($count -ne $ExpectedCount) {
    throw "Pinned native New Tab anchor changed in $Path. Expected $ExpectedCount match(es), found ${count}: $Pattern"
  }
  $updated = $regex.Replace($text, $Replacement, $ExpectedCount)
  [IO.File]::WriteAllText($Path, $updated, [Text.UTF8Encoding]::new($false))
}

# Disable Chromium/Google-owned NTP network, AI, promo and cloud surfaces before
# they can initialize. Local shortcuts, local customization and the realbox stay.
$booleanRewrites = @(
  @('source->AddBoolean\(\s*"prefetchTriggerEnabled",\s*base::FeatureList::IsEnabled\(features::kNewTabPageTriggerForPrefetch\)\);', 'source->AddBoolean("prefetchTriggerEnabled", false);'),
  @('source->AddBoolean\(\s*"prerenderOnPressEnabled",\s*base::FeatureList::IsEnabled\(features::kNewTabPageTriggerForPrerender2\)\);', 'source->AddBoolean("prerenderOnPressEnabled", false);'),
  @('source->AddBoolean\(\s*"oneGoogleBarEnabled",\s*base::FeatureList::IsEnabled\(ntp_features::kNtpOneGoogleBar\)\);', 'source->AddBoolean("oneGoogleBarEnabled", false);'),
  @('source->AddBoolean\("logoEnabled",\s*base::FeatureList::IsEnabled\(ntp_features::kNtpLogo\)\);', 'source->AddBoolean("logoEnabled", true);'),
  @('source->AddBoolean\(\s*"animatedDoodlesEnabled",\s*base::FeatureList::IsEnabled\(ntp_features::kNtpAnimatedDoodles\)\);', 'source->AddBoolean("animatedDoodlesEnabled", false);'),
  @('source->AddBoolean\(\s*"doodleMuralsEnabled",\s*base::FeatureList::IsEnabled\(ntp_features::kNtpDoodleMurals\)\);', 'source->AddBoolean("doodleMuralsEnabled", false);'),
  @('source->AddBoolean\(\s*"modulesLoadEnabled",\s*base::FeatureList::IsEnabled\(ntp_features::kNtpModulesLoad\)\);', 'source->AddBoolean("modulesLoadEnabled", false);'),
  @('source->AddBoolean\(\s*"searchboxShowComposeEntrypoint",\s*\(aim_eligible \|\| ntp_composebox::IsNtpComposeboxEnabled\(profile\)\)\);', 'source->AddBoolean("searchboxShowComposeEntrypoint", false);'),
  @('source->AddBoolean\(\s*"ntpRealboxDynamicAiModeButton",\s*ntp_realbox::IsNtpRealboxNextEnabled\(profile\) &&\s*base::FeatureList::IsEnabled\(\s*ntp_realbox::kNtpRealboxDynamicAiModeButton\)\);', 'source->AddBoolean("ntpRealboxDynamicAiModeButton", false);'),
  @('source->AddBoolean\("searchboxShowComposebox",\s*ntp_composebox::IsNtpComposeboxEnabled\(profile\)\);', 'source->AddBoolean("searchboxShowComposebox", false);'),
  @('source->AddBoolean\("enableThreadsRail",\s*base::FeatureList::IsEnabled\(\s*ntp_features::kNtpThreadsRail\)\);', 'source->AddBoolean("enableThreadsRail", false);'),
  @('source->AddBoolean\("actionChipsEnabled", show_action_chips\);', 'source->AddBoolean("actionChipsEnabled", false);'),
  @('source->AddInteger\("browserPromoLimit", browser_promo_limit\);', 'source->AddInteger("browserPromoLimit", 0);')
)
foreach ($rewrite in $booleanRewrites) {
  Replace-RequiredPattern -Path $uiPath -Pattern $rewrite[0] -Replacement $rewrite[1]
}

Replace-RequiredPattern -Path $uiPath `
  -Pattern 'bool microsoft_module_enabled = IsMicrosoftModuleEnabledForProfile\(profile\);' `
  -Replacement 'bool microsoft_module_enabled = false;'
Replace-RequiredPattern -Path $uiPath `
  -Pattern '\.enable_voice_search = true,' `
  -Replacement '.enable_voice_search = false,'
Replace-RequiredPattern -Path $uiPath `
  -Pattern '\.enable_lens_search = profile->GetPrefs\(\)->GetBoolean\(\s*prefs::kLensDesktopNTPSearchEnabled\),' `
  -Replacement '.enable_lens_search = false,'

# Keep the search provider external and truthful, but remove provider/product
# branding from Ghosium's own search box placeholder.
Replace-RequiredPattern -Path $uiPath `
  -Pattern 'if \(ntp_realbox::IsNtpRealboxNextEnabled\(profile\)\) \{.*?\}\s*else \{\s*source->AddLocalizedString\("searchBoxPlaceholder",\s*IDS_GOOGLE_SEARCH_BOX_EMPTY_HINT_MD\);\s*\}' `
  -Replacement 'source->AddString("searchBoxPlaceholder", l10n_util::GetStringFUTF16(IDS_WEBUI_OMNIBOX_PLACEHOLDER_TEXT, u"the web"));'

# The stock logo element fetches a remote Doodle in its constructor even when
# the final UI falls back to a static logo. Ghosium uses a local product mark
# and marks the component ready without that request.
Replace-RequiredPattern -Path $logoTsPath `
  -Pattern 'this\.pageHandler_ = NewTabPageProxy\.getInstance\(\)\.handler;\s*this\.pageHandler_\.getDoodle\(\)\.then\(\(\{doodle\}\) => \{\s*this\.doodle_ = doodle;\s*this\.loaded_ = true;\s*\}\);' `
  -Replacement "this.pageHandler_ = NewTabPageProxy.getInstance().handler;`n    this.loaded_ = true;"
Replace-RequiredPattern -Path $logoTsPath `
  -Pattern '// Shows the Google logo or a doodle if available\.' `
  -Replacement '// Shows the local Ghosium product mark. Remote Doodles are disabled.'

Replace-RequiredPattern -Path $logoCssPath `
  -Pattern '#logo \{\s*forced-color-adjust: none;\s*height: 92px;\s*width: 272px;\s*\}' `
  -Replacement "#logo {`n  forced-color-adjust: none;`n  height: 112px;`n  width: 112px;`n}"
Replace-RequiredPattern -Path $logoCssPath `
  -Pattern ':host\(\[use-google-logo26_\]\) #logo \{\s*height: 82px;\s*width: 270px;\s*\}' `
  -Replacement ":host([use-google-logo26_]) #logo {`n  height: 112px;`n  width: 112px;`n}"

Copy-Item $brandSvg $logoAssetPath -Force

Write-Host 'Ghosium native New Tab privacy/branding hardening applied.'
