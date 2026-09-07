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
  throw "Windows executable verification requires pinned source $expectedRevision; found $actualRevision"
}

$checks = [ordered]@{
  'chrome/BUILD.gn' = @(
    '$root_out_dir/initialexe/Ghosium-Browser.exe',
    '$root_out_dir/initialexe/Ghosium-Browser.exe.pdb',
    '$root_out_dir/Ghosium-Browser.exe',
    '$root_out_dir/Ghosium-Browser.exe.pdb',
    '_chrome_output_name = "initialexe/Ghosium-Browser"'
  )
  'build/win/reorder-imports.py' = @(
    "os.path.join(input_dir, 'Ghosium-Browser.exe')",
    "os.path.join(output_dir, 'Ghosium-Browser.exe')",
    "os.path.join(input_dir, 'Ghosium-Browser.exe.*')"
  )
  'chrome/app/chrome_exe.ver' = @(
    'INTERNAL_NAME=Ghosium-Browser',
    'ORIGINAL_FILENAME=Ghosium-Browser.exe'
  )
  'chrome/installer/mini_installer/BUILD.gn' = @(
    '"$root_out_dir/Ghosium-Browser.exe",'
  )
  'chrome/installer/mini_installer/chrome.release' = @(
    'Ghosium-Browser.exe: %(ChromeDir)s\',
    'Ghosium-Proxy.exe: %(ChromeDir)s\'
  )
  'chrome/installer/util/util_constants.h' = @(
    'kChromeExe[] = L"Ghosium-Browser.exe"',
    'kChromeNewExe[] = L"new_Ghosium-Browser.exe"',
    'kChromeOldExe[] = L"old_Ghosium-Browser.exe"',
    'kChromeProxyExe[] = L"Ghosium-Proxy.exe"',
    'kChromeProxyNewExe[] = L"new_Ghosium-Proxy.exe"',
    'kChromeProxyOldExe[] = L"old_Ghosium-Proxy.exe"'
  )
  'chrome/installer/setup/setup_constants.cc' = @(
    'kVisualElementsManifest[] = L"Ghosium-Browser.VisualElementsManifest.xml"'
  )
  'chrome/installer/launcher_support/chrome_launcher_support.cc' = @(
    'kInstallationRegKey[] = L"Software\\Brendigo\\Ghosium"',
    'kChromeExe[] = L"Ghosium-Browser.exe"'
  )
  'chrome/chrome_proxy/BUILD.gn' = @(
    'output_name = "Ghosium-Proxy"'
  )
  'chrome/chrome_proxy/chrome_proxy.ver' = @(
    'INTERNAL_NAME=Ghosium-Proxy',
    'ORIGINAL_FILENAME=Ghosium-Proxy.exe'
  )
  'chrome/chrome_proxy/chrome_proxy_main_win.cc' = @(
    'FILE_PATH_LITERAL("Ghosium-Browser.exe")',
    'FILE_PATH_LITERAL("Ghosium-Proxy.exe")'
  )
}

foreach ($entry in $checks.GetEnumerator()) {
  $path = Join-Path $sourceRootResolved $entry.Key
  if (!(Test-Path $path -PathType Leaf)) {
    throw "Ghosium Windows executable verifier is missing source file: $($entry.Key)"
  }
  $text = [IO.File]::ReadAllText($path)
  foreach ($needle in $entry.Value) {
    if (!$text.Contains($needle)) {
      throw "Ghosium Windows executable verifier failed in $($entry.Key): missing $needle"
    }
  }
}

$forbidden = [ordered]@{
  'chrome/BUILD.gn' = @(
    '$root_out_dir/initialexe/chrome.exe',
    '$root_out_dir/chrome.exe',
    '_chrome_output_name = "initialexe/chrome"'
  )
  'build/win/reorder-imports.py' = @(
    "os.path.join(input_dir, 'chrome.exe')",
    "os.path.join(output_dir, 'chrome.exe')"
  )
  'chrome/app/chrome_exe.ver' = @(
    'ORIGINAL_FILENAME=chrome.exe'
  )
  'chrome/installer/mini_installer/BUILD.gn' = @(
    '"$root_out_dir/chrome.exe",'
  )
  'chrome/installer/mini_installer/chrome.release' = @(
    'chrome.exe: %(ChromeDir)s\',
    'chrome_proxy.exe: %(ChromeDir)s\'
  )
  'chrome/installer/util/util_constants.h' = @(
    'kChromeExe[] = L"chrome.exe"',
    'kChromeProxyExe[] = L"chrome_proxy.exe"'
  )
  'chrome/installer/setup/setup_constants.cc' = @(
    'kVisualElementsManifest[] = L"chrome.VisualElementsManifest.xml"'
  )
  'chrome/installer/launcher_support/chrome_launcher_support.cc' = @(
    'kInstallationRegKey[] = L"Software\\Chromium"',
    'kChromeExe[] = L"chrome.exe"'
  )
  'chrome/chrome_proxy/chrome_proxy.ver' = @(
    'ORIGINAL_FILENAME=chrome_proxy.exe'
  )
  'chrome/chrome_proxy/chrome_proxy_main_win.cc' = @(
    'FILE_PATH_LITERAL("chrome.exe")',
    'FILE_PATH_LITERAL("chrome_proxy.exe")'
  )
}

foreach ($entry in $forbidden.GetEnumerator()) {
  $path = Join-Path $sourceRootResolved $entry.Key
  $text = [IO.File]::ReadAllText($path)
  foreach ($needle in $entry.Value) {
    if ($text.Contains($needle)) {
      throw "Legacy public Windows executable identity remains in $($entry.Key): $needle"
    }
  }
}

# Internal library names are intentionally outside this milestone. They remain
# Chromium-compatible technical implementation details until a separate full
# compile/runtime migration proves a coordinated DLL rename safe.
$utilText = [IO.File]::ReadAllText((Join-Path $sourceRootResolved 'chrome/installer/util/util_constants.h'))
if (!$utilText.Contains('kChromeDll[] = L"chrome.dll"')) {
  throw 'chrome.dll technical compatibility name changed unexpectedly; review DLL migration separately.'
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party state during Windows executable verification.'
}
if ($thirdPartyChanges) {
  throw 'Windows executable verification detected third_party modifications.'
}

Write-Host 'Ghosium Windows executable identity verifier: OK (Ghosium-Browser.exe / Ghosium-Proxy.exe)'
