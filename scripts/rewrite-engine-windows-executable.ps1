param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedRevision = (Get-Content (Join-Path $repoRoot 'ENGINE_SOURCE_REVISION') -Raw).Trim()
$sourceRootResolved = (Resolve-Path $SourceRoot).Path

$actualRevision = (& git -C $sourceRootResolved rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualRevision -ne $expectedRevision) {
  throw "Refusing to rewrite Windows executable identity on an unpinned checkout. Expected $expectedRevision; found $actualRevision"
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
    throw "Pinned Chromium executable-identity anchor changed in ${Path}: $OldValue"
  }
}

$chromeBuild = Join-Path $sourceRootResolved 'chrome/BUILD.gn'
$reorderImports = Join-Path $sourceRootResolved 'build/win/reorder-imports.py'
$chromeExeVersion = Join-Path $sourceRootResolved 'chrome/app/chrome_exe.ver'
$miniInstallerBuild = Join-Path $sourceRootResolved 'chrome/installer/mini_installer/BUILD.gn'
$miniInstallerRelease = Join-Path $sourceRootResolved 'chrome/installer/mini_installer/chrome.release'
$utilConstants = Join-Path $sourceRootResolved 'chrome/installer/util/util_constants.h'
$setupConstants = Join-Path $sourceRootResolved 'chrome/installer/setup/setup_constants.cc'
$launcherSupport = Join-Path $sourceRootResolved 'chrome/installer/launcher_support/chrome_launcher_support.cc'
$proxyBuild = Join-Path $sourceRootResolved 'chrome/chrome_proxy/BUILD.gn'
$proxyVersion = Join-Path $sourceRootResolved 'chrome/chrome_proxy/chrome_proxy.ver'
$proxyMain = Join-Path $sourceRootResolved 'chrome/chrome_proxy/chrome_proxy_main_win.cc'

foreach ($required in @(
  $chromeBuild,
  $reorderImports,
  $chromeExeVersion,
  $miniInstallerBuild,
  $miniInstallerRelease,
  $utilConstants,
  $setupConstants,
  $launcherSupport,
  $proxyBuild,
  $proxyVersion,
  $proxyMain
)) {
  if (!(Test-Path $required -PathType Leaf)) {
    throw "Pinned source layout changed; Windows executable-identity target is missing: $required"
  }
}

# Primary browser binary. Keep the GN target name //chrome:chrome as a technical
# dependency, but change the produced Windows image and its PDB together.
foreach ($replacement in @(
  @('$root_out_dir/initialexe/chrome.exe', '$root_out_dir/initialexe/Ghosium-Browser.exe'),
  @('$root_out_dir/initialexe/chrome.exe.pdb', '$root_out_dir/initialexe/Ghosium-Browser.exe.pdb'),
  @('$root_out_dir/chrome.exe', '$root_out_dir/Ghosium-Browser.exe'),
  @('$root_out_dir/chrome.exe.pdb', '$root_out_dir/Ghosium-Browser.exe.pdb'),
  @('_chrome_output_name = "initialexe/chrome"', '_chrome_output_name = "initialexe/Ghosium-Browser"')
)) {
  Replace-RequiredLiteral -Path $chromeBuild -OldValue $replacement[0] -NewValue $replacement[1]
}

# The Windows import reorder step is part of producing the final browser PE and
# must use the same renamed input/output image and associated PDB sidecars.
Replace-RequiredLiteral -Path $reorderImports -OldValue "os.path.join(input_dir, 'chrome.exe')" -NewValue "os.path.join(input_dir, 'Ghosium-Browser.exe')"
Replace-RequiredLiteral -Path $reorderImports -OldValue "os.path.join(output_dir, 'chrome.exe')" -NewValue "os.path.join(output_dir, 'Ghosium-Browser.exe')"
Replace-RequiredLiteral -Path $reorderImports -OldValue "os.path.join(input_dir, 'chrome.exe.*')" -NewValue "os.path.join(input_dir, 'Ghosium-Browser.exe.*')"

# Windows file properties must not retain chrome.exe as the original filename.
Replace-RequiredLiteral -Path $chromeExeVersion -OldValue 'INTERNAL_NAME=chrome_exe' -NewValue 'INTERNAL_NAME=Ghosium-Browser'
Replace-RequiredLiteral -Path $chromeExeVersion -OldValue 'ORIGINAL_FILENAME=chrome.exe' -NewValue 'ORIGINAL_FILENAME=Ghosium-Browser.exe'

# The installer archive must consume and install the renamed primary image.
Replace-RequiredLiteral -Path $miniInstallerBuild -OldValue '"$root_out_dir/chrome.exe",' -NewValue '"$root_out_dir/Ghosium-Browser.exe",'
Replace-RequiredLiteral -Path $miniInstallerRelease -OldValue 'chrome.exe: %(ChromeDir)s\' -NewValue 'Ghosium-Browser.exe: %(ChromeDir)s\'

# Installer/update/shortcut code centralizes primary and proxy image filenames in
# util_constants.h. Renaming these values keeps setup, update and uninstall flows
# coordinated instead of patching their call sites individually.
foreach ($replacement in @(
  @('kChromeExe[] = L"chrome.exe"', 'kChromeExe[] = L"Ghosium-Browser.exe"'),
  @('kChromeNewExe[] = L"new_chrome.exe"', 'kChromeNewExe[] = L"new_Ghosium-Browser.exe"'),
  @('kChromeOldExe[] = L"old_chrome.exe"', 'kChromeOldExe[] = L"old_Ghosium-Browser.exe"'),
  @('kChromeProxyExe[] = L"chrome_proxy.exe"', 'kChromeProxyExe[] = L"Ghosium-Proxy.exe"'),
  @('kChromeProxyNewExe[] = L"new_chrome_proxy.exe"', 'kChromeProxyNewExe[] = L"new_Ghosium-Proxy.exe"'),
  @('kChromeProxyOldExe[] = L"old_chrome_proxy.exe"', 'kChromeProxyOldExe[] = L"old_Ghosium-Proxy.exe"')
)) {
  Replace-RequiredLiteral -Path $utilConstants -OldValue $replacement[0] -NewValue $replacement[1]
}

# Windows associates the VisualElements manifest with the primary executable
# basename. Keep the installed manifest basename synchronized with the rename.
Replace-RequiredLiteral -Path $setupConstants -OldValue 'kVisualElementsManifest[] = L"chrome.VisualElementsManifest.xml"' -NewValue 'kVisualElementsManifest[] = L"Ghosium-Browser.VisualElementsManifest.xml"'

# launcher_support has a historical duplicated filename constant and Chromium
# registry fallback instead of consuming util_constants.h. Keep both aligned.
Replace-RequiredLiteral -Path $launcherSupport -OldValue 'kInstallationRegKey[] = L"Software\\Chromium"' -NewValue 'kInstallationRegKey[] = L"Software\\Brendigo\\Ghosium"'
Replace-RequiredLiteral -Path $launcherSupport -OldValue 'kChromeExe[] = L"chrome.exe"' -NewValue 'kChromeExe[] = L"Ghosium-Browser.exe"'

# PWA/bookmark proxy remains a separate helper target but gets a Ghosium output
# filename and launches the renamed primary browser image.
Replace-RequiredLiteral -Path $proxyBuild -OldValue 'executable("chrome_proxy") {' -NewValue "executable(`"chrome_proxy`") {`n  output_name = `"Ghosium-Proxy`""
Replace-RequiredLiteral -Path $proxyVersion -OldValue 'INTERNAL_NAME=chrome_proxy' -NewValue 'INTERNAL_NAME=Ghosium-Proxy'
Replace-RequiredLiteral -Path $proxyVersion -OldValue 'ORIGINAL_FILENAME=chrome_proxy.exe' -NewValue 'ORIGINAL_FILENAME=Ghosium-Proxy.exe'
Replace-RequiredLiteral -Path $proxyMain -OldValue 'FILE_PATH_LITERAL("chrome.exe")' -NewValue 'FILE_PATH_LITERAL("Ghosium-Browser.exe")'
Replace-RequiredLiteral -Path $proxyMain -OldValue 'FILE_PATH_LITERAL("chrome_proxy.exe")' -NewValue 'FILE_PATH_LITERAL("Ghosium-Proxy.exe")'
Replace-RequiredLiteral -Path $miniInstallerRelease -OldValue 'chrome_proxy.exe: %(ChromeDir)s\' -NewValue 'Ghosium-Proxy.exe: %(ChromeDir)s\'

# Verify the coordinated primary/proxy identity and explicitly reject active old
# Windows image basenames in the source files that own these contracts.
$requiredState = [ordered]@{
  $chromeBuild = @('initialexe/Ghosium-Browser.exe', '$root_out_dir/Ghosium-Browser.exe', '_chrome_output_name = "initialexe/Ghosium-Browser"')
  $reorderImports = @("'Ghosium-Browser.exe'", "'Ghosium-Browser.exe.*'")
  $chromeExeVersion = @('INTERNAL_NAME=Ghosium-Browser', 'ORIGINAL_FILENAME=Ghosium-Browser.exe')
  $miniInstallerBuild = @('$root_out_dir/Ghosium-Browser.exe')
  $miniInstallerRelease = @('Ghosium-Browser.exe: %(ChromeDir)s\', 'Ghosium-Proxy.exe: %(ChromeDir)s\')
  $utilConstants = @('kChromeExe[] = L"Ghosium-Browser.exe"', 'kChromeProxyExe[] = L"Ghosium-Proxy.exe"')
  $setupConstants = @('kVisualElementsManifest[] = L"Ghosium-Browser.VisualElementsManifest.xml"')
  $launcherSupport = @('kInstallationRegKey[] = L"Software\\Brendigo\\Ghosium"', 'kChromeExe[] = L"Ghosium-Browser.exe"')
  $proxyBuild = @('output_name = "Ghosium-Proxy"')
  $proxyVersion = @('ORIGINAL_FILENAME=Ghosium-Proxy.exe')
  $proxyMain = @('FILE_PATH_LITERAL("Ghosium-Browser.exe")', 'FILE_PATH_LITERAL("Ghosium-Proxy.exe")')
}
foreach ($entry in $requiredState.GetEnumerator()) {
  $text = [IO.File]::ReadAllText($entry.Key)
  foreach ($needle in $entry.Value) {
    if (!$text.Contains($needle)) {
      throw "Ghosium Windows executable identity verification failed in $($entry.Key): missing $needle"
    }
  }
}

foreach ($legacy in @(
  @($chromeBuild, '$root_out_dir/chrome.exe'),
  @($chromeExeVersion, 'ORIGINAL_FILENAME=chrome.exe'),
  @($miniInstallerBuild, '$root_out_dir/chrome.exe'),
  @($miniInstallerRelease, 'chrome.exe: %(ChromeDir)s\'),
  @($miniInstallerRelease, 'chrome_proxy.exe: %(ChromeDir)s\'),
  @($utilConstants, 'kChromeExe[] = L"chrome.exe"'),
  @($utilConstants, 'kChromeProxyExe[] = L"chrome_proxy.exe"'),
  @($launcherSupport, 'kChromeExe[] = L"chrome.exe"'),
  @($proxyVersion, 'ORIGINAL_FILENAME=chrome_proxy.exe'),
  @($proxyMain, 'FILE_PATH_LITERAL("chrome.exe")'),
  @($proxyMain, 'FILE_PATH_LITERAL("chrome_proxy.exe")')
)) {
  if ([IO.File]::ReadAllText($legacy[0]).Contains($legacy[1])) {
    throw "Legacy Windows executable identity remains active in $($legacy[0]): $($legacy[1])"
  }
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party source state after Windows executable rename.'
}
if ($thirdPartyChanges) {
  throw 'Windows executable identity rewrite modified third_party sources; refusing to continue.'
}

Write-Host 'Ghosium Windows primary/proxy executable identity applied: Ghosium-Browser.exe + Ghosium-Proxy.exe'
