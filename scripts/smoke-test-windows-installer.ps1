param(
  [Parameter(Mandatory = $true)]
  [string]$SetupPath,

  [Parameter(Mandatory = $true)]
  [string]$Version,

  [Parameter(Mandatory = $false)]
  [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
  throw 'The Ghosium canonical Setup smoke test must run on Windows.'
}
if ($Version -notmatch '^0\.[1-9]\d*\.\d+$') {
  throw "Version must use the Ghosium 0.x.y line; received '$Version'."
}

$setup = (Resolve-Path $SetupPath).Path
$setupItem = Get-Item $setup
if ($setupItem.Name -ne 'Ghosium-Browser-Setup.exe' -or $setupItem.Length -le 0) {
  throw "SetupPath must be a non-empty Ghosium-Browser-Setup.exe: $setup"
}
$setupHash = (Get-FileHash $setup -Algorithm SHA256).Hash.ToLowerInvariant()
$setupInfo = $setupItem.VersionInfo
if ([string]$setupInfo.ProductName -ne 'Ghosium Browser') {
  throw "Setup ProductName mismatch: '$($setupInfo.ProductName)'"
}
if ([string]$setupInfo.CompanyName -ne 'Brendigo') {
  throw "Setup CompanyName mismatch: '$($setupInfo.CompanyName)'"
}
if ([string]$setupInfo.ProductVersion -notlike "$Version*") {
  throw "Setup ProductVersion mismatch: '$($setupInfo.ProductVersion)' expected '$Version'."
}

$tempBase = if (![string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
  $env:RUNNER_TEMP
} else {
  [IO.Path]::GetTempPath()
}
$root = Join-Path $tempBase "GhosiumCanonicalSetupSmoke-$PID"
$profile = Join-Path $tempBase "GhosiumCanonicalProfileSmoke-$PID"
$runtimeStdout = Join-Path $tempBase "ghosium-canonical-runtime-$PID.stdout.txt"
$runtimeStderr = Join-Path $tempBase "ghosium-canonical-runtime-$PID.stderr.txt"
$installedSetup = Join-Path $root 'Installer\Ghosium-Browser-Setup.exe'
$browser = Join-Path $root 'Ghosium-Browser.exe'
$marker = Join-Path $root 'ghosium-install.marker'
$languageFile = Join-Path $root 'ghosium-language.txt'
$license = Join-Path $root 'LICENSE'
$thirdPartyNotices = Join-Path $root 'THIRD_PARTY_NOTICES.md'
$uninstallKeyPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\GhosiumBrowser'
$updateDir = Join-Path $env:TEMP 'Brendigo\Ghosium Browser Update'
$updateSetup = Join-Path $updateDir 'Ghosium-Browser-Setup.exe'
$cleanupDir = Join-Path $env:TEMP 'Brendigo\Ghosium Browser Cleanup'
$profileSentinel = Join-Path $profile 'ghosium-update-profile-sentinel.txt'

function Invoke-ProcessWithTimeout {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$ArgumentList,
    [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
    [Parameter(Mandatory = $true)][string]$Description,
    [Parameter(Mandatory = $false)][string]$RedirectStandardOutput,
    [Parameter(Mandatory = $false)][string]$RedirectStandardError
  )

  $parameters = @{
    FilePath = $FilePath
    ArgumentList = $ArgumentList
    PassThru = $true
  }
  if ($RedirectStandardOutput) {
    $parameters.RedirectStandardOutput = $RedirectStandardOutput
  }
  if ($RedirectStandardError) {
    $parameters.RedirectStandardError = $RedirectStandardError
  }

  $process = Start-Process @parameters
  if (!$process.WaitForExit($TimeoutSeconds * 1000)) {
    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    throw "$Description timed out after $TimeoutSeconds seconds."
  }
  $process.Refresh()
  if ($process.ExitCode -ne 0) {
    throw "$Description failed with exit code $($process.ExitCode)."
  }
  return $process
}

function Wait-ForCondition {
  param(
    [Parameter(Mandatory = $true)][scriptblock]$Condition,
    [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
    [Parameter(Mandatory = $true)][string]$Description
  )

  $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
  while ([DateTime]::UtcNow -lt $deadline) {
    if (& $Condition) {
      return
    }
    Start-Sleep -Milliseconds 400
  }
  throw "Timed out waiting for $Description."
}

function Assert-RegisteredInstallation {
  if (!(Test-Path $uninstallKeyPath)) {
    throw 'Ghosium uninstall registry entry was not created.'
  }
  $reg = Get-ItemProperty $uninstallKeyPath
  if ([string]$reg.DisplayName -ne 'Ghosium Browser') {
    throw "Installed Apps DisplayName mismatch: '$($reg.DisplayName)'"
  }
  if ([string]$reg.DisplayVersion -ne $Version) {
    throw "Installed Apps DisplayVersion mismatch: '$($reg.DisplayVersion)'"
  }
  if ([string]$reg.Publisher -ne 'Brendigo') {
    throw "Installed Apps Publisher mismatch: '$($reg.Publisher)'"
  }
  if ([IO.Path]::GetFullPath([string]$reg.InstallLocation).TrimEnd('\') -ne
      [IO.Path]::GetFullPath($root).TrimEnd('\')) {
    throw "Installed Apps InstallLocation mismatch: '$($reg.InstallLocation)'"
  }

  $uninstallString = [string]$reg.UninstallString
  $quietUninstallString = [string]$reg.QuietUninstallString
  if (!$uninstallString.Contains('Ghosium-Browser-Setup.exe') -or !$uninstallString.Contains('/UNINSTALL')) {
    throw "UninstallString does not use the same Ghosium Setup executable: '$uninstallString'"
  }
  if ($uninstallString -match '(?i)(^|[\\/])uninstall\.exe') {
    throw "UninstallString references a standalone uninstaller: '$uninstallString'"
  }
  if (!$quietUninstallString.Contains('Ghosium-Browser-Setup.exe') -or
      !$quietUninstallString.Contains('/UNINSTALL') -or
      !$quietUninstallString.Contains('/S')) {
    throw "QuietUninstallString is invalid: '$quietUninstallString'"
  }
  if ($quietUninstallString.IndexOf('/S', [StringComparison]::Ordinal) -gt
      $quietUninstallString.IndexOf('/UNINSTALL', [StringComparison]::Ordinal)) {
    throw "QuietUninstallString must place /S before /UNINSTALL: '$quietUninstallString'"
  }
  return $reg
}

function Assert-InstalledPayload {
  foreach ($required in @($installedSetup, $browser, $marker, $languageFile, $license, $thirdPartyNotices)) {
    if (!(Test-Path $required -PathType Leaf) -or (Get-Item $required).Length -le 0) {
      throw "Installed Ghosium file is missing or empty: $required"
    }
  }

  $markerText = (Get-Content $marker -Raw).Trim()
  if ($markerText -ne "Ghosium Browser|$Version") {
    throw "Ghosium install marker mismatch: '$markerText'"
  }

  $installedSetupHash = (Get-FileHash $installedSetup -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($installedSetupHash -ne $setupHash) {
    throw 'Installed maintenance Setup does not match the canonical public Setup package.'
  }

  $browserInfo = (Get-Item $browser).VersionInfo
  if ([string]$browserInfo.ProductName -ne 'Ghosium Browser' -or
      [string]$browserInfo.CompanyName -ne 'Brendigo') {
    throw "Installed Ghosium-Browser.exe metadata mismatch: ProductName='$($browserInfo.ProductName)' CompanyName='$($browserInfo.CompanyName)'"
  }

  foreach ($forbidden in @(
    'chrome.exe',
    'chrome_proxy.exe',
    'update.exe',
    'updater.exe',
    'uninstall.exe',
    'Ghosium-Update.exe',
    'Ghosium-Updater.exe',
    'Ghosium-Uninstall.exe'
  )) {
    $match = Get-ChildItem $root -Recurse -File -Force -ErrorAction Stop |
      Where-Object { $_.Name -ieq $forbidden } |
      Select-Object -First 1
    if ($match) {
      throw "Forbidden legacy/standalone executable exists in installed Ghosium payload: $($match.FullName)"
    }
  }
}

function Invoke-InstalledRuntimeSmoke {
  if (Test-Path $runtimeStdout) { Remove-Item $runtimeStdout -Force }
  if (Test-Path $runtimeStderr) { Remove-Item $runtimeStderr -Force }

  $arguments = @(
    '--headless=new',
    '--disable-gpu',
    '--disable-sync',
    '--no-pings',
    '--no-first-run',
    "--user-data-dir=$profile",
    '--dump-dom',
    'data:text/html,<html><body>ghosium-canonical-installed-runtime-ok</body></html>'
  )
  [void](Invoke-ProcessWithTimeout `
    -FilePath $browser `
    -ArgumentList $arguments `
    -TimeoutSeconds 60 `
    -Description 'Installed canonical Ghosium runtime smoke' `
    -RedirectStandardOutput $runtimeStdout `
    -RedirectStandardError $runtimeStderr)

  $stdout = if (Test-Path $runtimeStdout -PathType Leaf) { Get-Content $runtimeStdout -Raw } else { '' }
  $stderr = if (Test-Path $runtimeStderr -PathType Leaf) { Get-Content $runtimeStderr -Raw } else { '' }
  if (!$stdout.Contains('ghosium-canonical-installed-runtime-ok')) {
    Write-Host $stdout
    Write-Host $stderr
    throw 'Installed canonical Ghosium runtime did not return the expected DOM marker.'
  }
}

$preexistingInstall = Test-Path $root
$preexistingRegistration = Test-Path $uninstallKeyPath
if ($preexistingInstall -or $preexistingRegistration) {
  throw 'Canonical Setup smoke test refuses to overwrite an existing smoke installation/registration.'
}

$installCompleted = $false
$updateCompleted = $false
$updateCleanupCompleted = $false
$runtimeBeforeUpdate = $false
$runtimeAfterUpdate = $false
$profilePreservedAcrossUpdate = $false
$profilePreservedAfterUninstall = $false
$uninstallCompleted = $false
$languageBeforeUpdate = ''
$languageAfterUpdate = ''

try {
  foreach ($path in @($updateDir, $cleanupDir)) {
    if (Test-Path $path) {
      Remove-Item $path -Recurse -Force -ErrorAction Stop
    }
  }
  if (Test-Path $profile) {
    Remove-Item $profile -Recurse -Force -ErrorAction Stop
  }

  [void](Invoke-ProcessWithTimeout `
    -FilePath $setup `
    -ArgumentList @('/S', "/D=$root") `
    -TimeoutSeconds 180 `
    -Description 'Canonical Ghosium silent install')
  $installCompleted = $true

  Assert-InstalledPayload
  [void](Assert-RegisteredInstallation)
  $languageBeforeUpdate = (Get-Content $languageFile -Raw).Trim()

  Invoke-InstalledRuntimeSmoke
  $runtimeBeforeUpdate = $true
  New-Item -ItemType Directory -Force -Path $profile | Out-Null
  [IO.File]::WriteAllText($profileSentinel, 'preserve-across-ghosium-update', [Text.UTF8Encoding]::new($false))

  # Mirror the native browser updater exactly: it downloads the canonical Setup
  # to this fixed private temp location and launches /S /UPDATE /DELETESELF.
  New-Item -ItemType Directory -Force -Path $updateDir | Out-Null
  Copy-Item $setup $updateSetup -Force
  if ((Get-FileHash $updateSetup -Algorithm SHA256).Hash.ToLowerInvariant() -ne $setupHash) {
    throw 'Staged browser-update Setup hash differs from the canonical package.'
  }

  [void](Invoke-ProcessWithTimeout `
    -FilePath $updateSetup `
    -ArgumentList @('/S', '/UPDATE', '/DELETESELF') `
    -TimeoutSeconds 180 `
    -Description 'Canonical Ghosium same-Setup update')
  $updateCompleted = $true

  Wait-ForCondition `
    -Condition { !(Test-Path $updateSetup -PathType Leaf) } `
    -TimeoutSeconds 60 `
    -Description 'downloaded Ghosium update Setup cleanup'
  $updateCleanupCompleted = $true

  Assert-InstalledPayload
  [void](Assert-RegisteredInstallation)
  $languageAfterUpdate = (Get-Content $languageFile -Raw).Trim()
  if ($languageAfterUpdate -ne $languageBeforeUpdate) {
    throw "Ghosium installer language changed during update: '$languageBeforeUpdate' -> '$languageAfterUpdate'"
  }
  if (!(Test-Path $profileSentinel -PathType Leaf) -or
      (Get-Content $profileSentinel -Raw) -ne 'preserve-across-ghosium-update') {
    throw 'Ghosium user profile sentinel was lost or modified during /UPDATE.'
  }
  $profilePreservedAcrossUpdate = $true

  Invoke-InstalledRuntimeSmoke
  $runtimeAfterUpdate = $true

  [void](Invoke-ProcessWithTimeout `
    -FilePath $installedSetup `
    -ArgumentList @('/S', '/UNINSTALL') `
    -TimeoutSeconds 60 `
    -Description 'Canonical Ghosium same-Setup uninstall launcher')

  Wait-ForCondition `
    -Condition { !(Test-Path $root) -and !(Test-Path $uninstallKeyPath) } `
    -TimeoutSeconds 75 `
    -Description 'Ghosium application directory and uninstall registration removal'
  $uninstallCompleted = $true

  if (!(Test-Path $profileSentinel -PathType Leaf)) {
    throw 'Normal Ghosium uninstall unexpectedly removed the external browser profile used by the smoke test.'
  }
  $profilePreservedAfterUninstall = $true

  if (!$ReportPath) {
    $ReportPath = Join-Path $tempBase "GHOSIUM-CANONICAL-SETUP-SMOKE-$PID.json"
  } elseif (![IO.Path]::IsPathRooted($ReportPath)) {
    $ReportPath = [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $ReportPath))
  }

  $signature = Get-AuthenticodeSignature $setup
  $report = [ordered]@{
    schemaVersion = 2
    product = 'Ghosium Browser'
    version = $Version
    setup = [ordered]@{
      fileName = $setupItem.Name
      bytes = [int64]$setupItem.Length
      sha256 = $setupHash
      authenticodeStatus = [string]$signature.Status
      signerSubject = if ($signature.SignerCertificate) { [string]$signature.SignerCertificate.Subject } else { '' }
    }
    install = [ordered]@{
      completed = $installCompleted
      installedSetupMatchesCanonicalPackage = $true
      publicExecutableIdentityComplete = $true
      registrationVerified = $true
      legalPayloadInstalled = $true
    }
    update = [ordered]@{
      completed = $updateCompleted
      browserUpdaterSwitches = @('/S', '/UPDATE', '/DELETESELF')
      downloadedSetupCleanupCompleted = $updateCleanupCompleted
      installedSetupRefreshed = $true
      languagePreserved = ($languageBeforeUpdate -eq $languageAfterUpdate)
      profilePreserved = $profilePreservedAcrossUpdate
    }
    runtime = [ordered]@{
      beforeUpdate = $runtimeBeforeUpdate
      afterUpdate = $runtimeAfterUpdate
    }
    uninstall = [ordered]@{
      sameSetupExecutable = $true
      completed = $uninstallCompleted
      applicationDirectoryRemoved = !(Test-Path $root)
      registrationRemoved = !(Test-Path $uninstallKeyPath)
      normalUninstallPreservedProfile = $profilePreservedAfterUninstall
    }
    forbiddenStandaloneMaintenanceExecutables = $false
  }

  $reportDirectory = Split-Path -Parent $ReportPath
  if ($reportDirectory -and !(Test-Path $reportDirectory -PathType Container)) {
    New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
  }
  [IO.File]::WriteAllText(
    $ReportPath,
    (($report | ConvertTo-Json -Depth 8) + "`n"),
    [Text.UTF8Encoding]::new($false)
  )

  Write-Host 'Ghosium canonical Setup install -> runtime -> /UPDATE /DELETESELF -> runtime -> same-Setup uninstall smoke test: OK'
  Write-Host "Smoke report: $ReportPath"
}
finally {
  if (Test-Path $uninstallKeyPath) {
    Remove-Item $uninstallKeyPath -Recurse -Force -ErrorAction SilentlyContinue
  }
  foreach ($path in @($root, $profile, $updateDir, $cleanupDir)) {
    if (Test-Path $path) {
      Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
  foreach ($path in @($runtimeStdout, $runtimeStderr)) {
    if (Test-Path $path -PathType Leaf) {
      Remove-Item $path -Force -ErrorAction SilentlyContinue
    }
  }
}
