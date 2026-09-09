param(
  [Parameter(Mandatory = $false)]
  [string]$ArtifactsDir
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
  throw 'The Ghosium installer contract fixture must run on Windows.'
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$version = (Get-Content (Join-Path $repoRoot 'VERSION') -Raw).Trim()
if ($version -notmatch '^0\.\d+\.\d+$') {
  throw "Ghosium VERSION is invalid: '$version'"
}

$tempBase = if (![string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
  $env:RUNNER_TEMP
} else {
  [IO.Path]::GetTempPath()
}
$work = Join-Path $tempBase "ghosium-installer-contract-$PID"
$stage = Join-Path $work 'stage'
if ([string]::IsNullOrWhiteSpace($ArtifactsDir)) {
  $ArtifactsDir = Join-Path $work 'artifacts'
}
$artifacts = [IO.Path]::GetFullPath($ArtifactsDir)
$report = Join-Path $artifacts 'GHOSIUM-INSTALLER-CONTRACT-SMOKE.json'

if (Test-Path $work) {
  Remove-Item $work -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $stage, $artifacts | Out-Null

try {
  Copy-Item (Join-Path $repoRoot 'LICENSE') (Join-Path $stage 'LICENSE') -Force
  Copy-Item (Join-Path $repoRoot 'THIRD_PARTY_NOTICES.md') (Join-Path $stage 'THIRD_PARTY_NOTICES.md') -Force

  $sourcePath = Join-Path $work 'GhosiumFixture.cs'
  $browserPath = Join-Path $stage 'Ghosium-Browser.exe'
  $proxyPath = Join-Path $stage 'Ghosium-Proxy.exe'
  $assemblyVersion = "$version.0"
  $source = @"
using System;
using System.Reflection;
[assembly: AssemblyTitle("Ghosium Browser")]
[assembly: AssemblyProduct("Ghosium Browser")]
[assembly: AssemblyCompany("Brendigo")]
[assembly: AssemblyDescription("Ghosium Browser installer contract fixture")]
[assembly: AssemblyVersion("$assemblyVersion")]
[assembly: AssemblyFileVersion("$assemblyVersion")]
public static class Program {
  public static int Main(string[] args) {
    Console.WriteLine("<html><body>ghosium-canonical-installed-runtime-ok</body></html>");
    return 0;
  }
}
"@
  [IO.File]::WriteAllText($sourcePath, $source, [Text.UTF8Encoding]::new($false))

  $csc = @(
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
  ) | Where-Object { Test-Path $_ -PathType Leaf } | Select-Object -First 1
  if (!$csc) {
    throw 'Windows .NET Framework C# compiler was not found for the installer contract fixture.'
  }

  & $csc /nologo /target:exe /platform:anycpu /optimize+ "/out:$browserPath" $sourcePath | Out-Host
  if ($LASTEXITCODE -ne 0 -or !(Test-Path $browserPath -PathType Leaf)) {
    throw 'Unable to compile the Ghosium installer contract runtime fixture.'
  }
  Copy-Item $browserPath $proxyPath -Force

  $browserInfo = (Get-Item $browserPath).VersionInfo
  if ([string]$browserInfo.ProductName -ne 'Ghosium Browser' -or
      [string]$browserInfo.CompanyName -ne 'Brendigo' -or
      [string]$browserInfo.ProductVersion -notlike "$version*") {
    throw 'Fixture executable metadata does not satisfy the public Ghosium identity contract.'
  }

  $makensisOutput = @(& (Join-Path $repoRoot 'scripts/resolve-nsis.ps1') -Destination (Join-Path $work 'nsis'))
  $makensis = $makensisOutput |
    Where-Object { $_ -is [string] -and (Test-Path $_ -PathType Leaf) } |
    Select-Object -Last 1
  if (!$makensis) {
    throw 'Unable to resolve verified NSIS for the installer contract fixture.'
  }
  $makensis = (Resolve-Path $makensis).Path

  $nsi = Join-Path $repoRoot 'installer/ghosium.nsi'
  $portableNsi = Join-Path $repoRoot 'installer/ghosium-portable.nsi'
  $icon = Join-Path $repoRoot 'ghosium.ico'
  foreach ($required in @($nsi, $portableNsi, $icon, (Join-Path $repoRoot 'installer/assets/header.bmp'), (Join-Path $repoRoot 'installer/assets/welcome.bmp'))) {
    if (!(Test-Path $required -PathType Leaf)) {
      throw "Installer contract input is missing: $required"
    }
  }

  $setupPath = Join-Path $artifacts 'Ghosium-Browser-Setup.exe'
  & $makensis "/DGHOSIUM_VERSION=$version" "/DGHOSIUM_STAGE=$stage" "/DGHOSIUM_ARTIFACTS=$artifacts" "/DGHOSIUM_ICON=$icon" $nsi | Out-Host
  if ($LASTEXITCODE -ne 0 -or !(Test-Path $setupPath -PathType Leaf) -or (Get-Item $setupPath).Length -le 0) {
    throw 'Ghosium Setup contract compilation failed.'
  }

  $portablePath = Join-Path $artifacts 'Ghosium-Browser-Portable.exe'
  & $makensis "/DGHOSIUM_VERSION=$version" "/DGHOSIUM_STAGE=$stage" "/DGHOSIUM_ARTIFACTS=$artifacts" "/DGHOSIUM_ICON=$icon" '/DGHOSIUM_PORTABLE_PROFILE_SWITCH=--user-data-dir' $portableNsi | Out-Host
  if ($LASTEXITCODE -ne 0 -or !(Test-Path $portablePath -PathType Leaf) -or (Get-Item $portablePath).Length -le 0) {
    throw 'Ghosium Portable contract compilation failed.'
  }

  $setupInfo = (Get-Item $setupPath).VersionInfo
  if ([string]$setupInfo.ProductName -ne 'Ghosium Browser' -or
      [string]$setupInfo.CompanyName -ne 'Brendigo' -or
      [string]$setupInfo.FileDescription -ne 'Ghosium Browser Setup' -or
      [string]$setupInfo.ProductVersion -notlike "$version*") {
    throw 'Compiled Setup metadata failed the Ghosium contract.'
  }
  $portableInfo = (Get-Item $portablePath).VersionInfo
  if ([string]$portableInfo.ProductName -ne 'Ghosium Browser' -or
      [string]$portableInfo.CompanyName -ne 'Brendigo' -or
      [string]$portableInfo.FileDescription -ne 'Ghosium Browser Portable' -or
      [string]$portableInfo.ProductVersion -notlike "$version*") {
    throw 'Compiled Portable metadata failed the Ghosium contract.'
  }

  & (Join-Path $repoRoot 'scripts/smoke-test-windows-installer.ps1') `
    -SetupPath $setupPath `
    -Version $version `
    -ReportPath $report
  if ($LASTEXITCODE -ne 0) {
    throw 'Ghosium Setup lifecycle contract smoke failed.'
  }

  $smoke = Get-Content $report -Raw | ConvertFrom-Json
  if ($smoke.schemaVersion -ne 2 -or
      $smoke.product -ne 'Ghosium Browser' -or
      $smoke.version -ne $version -or
      !$smoke.install.completed -or
      !$smoke.update.completed -or
      !$smoke.runtime.beforeUpdate -or
      !$smoke.runtime.afterUpdate -or
      !$smoke.uninstall.sameSetupExecutable -or
      !$smoke.uninstall.completed -or
      $smoke.forbiddenStandaloneMaintenanceExecutables) {
    throw 'Ghosium installer fixture evidence failed the same-Setup lifecycle contract.'
  }

  Write-Host "Ghosium Windows installer contract: PASS ($version)"
  Write-Host "Setup: $setupPath"
  Write-Host "Portable: $portablePath"
  Write-Host "Evidence: $report"
} finally {
  # The lifecycle smoke owns and removes its installation root. Keep the build
  # artifacts only for the duration of this ephemeral CI job; always remove the
  # source fixture and any compiler scratch data.
  if (Test-Path $sourcePath -ErrorAction SilentlyContinue) {
    Remove-Item $sourcePath -Force -ErrorAction SilentlyContinue
  }
}
