param(
  [Parameter(Mandatory = $true)]
  [string]$MiniInstallerPath,

  [Parameter(Mandatory = $false)]
  [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT) {
  throw 'The Ghosium source-built installer smoke test must run on Windows.'
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$productLicense = Join-Path $repoRoot 'LICENSE'
$thirdPartyNotices = Join-Path $repoRoot 'THIRD_PARTY_NOTICES.md'
foreach ($requiredLegal in @($productLicense, $thirdPartyNotices)) {
  if (!(Test-Path $requiredLegal -PathType Leaf)) {
    throw "Source-installer smoke is missing canonical repository legal input: $requiredLegal"
  }
}
$expectedLicenseSha256 = (Get-FileHash $productLicense -Algorithm SHA256).Hash.ToLowerInvariant()
$expectedNoticesSha256 = (Get-FileHash $thirdPartyNotices -Algorithm SHA256).Hash.ToLowerInvariant()
$canonicalLicenseText = Get-Content $productLicense -Raw
if (!$canonicalLicenseText.Contains('Proprietary Commercial Software License Agreement') -or
    !$canonicalLicenseText.Contains('Open-source components remain governed by their respective licenses.')) {
  throw 'Canonical Ghosium product license does not satisfy the source-installer legal contract.'
}

$miniInstaller = (Resolve-Path $MiniInstallerPath).Path
$localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
if (!$localAppData) {
  throw 'Unable to resolve LOCALAPPDATA for the source-built installer smoke test.'
}

$productRoot = Join-Path $localAppData 'Brendigo\Ghosium'
$installRoot = Join-Path $productRoot 'Application'
$defaultUserDataRoot = Join-Path $productRoot 'User Data'
$uninstallRoot = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
$smokeRoot = Join-Path ([IO.Path]::GetTempPath()) "ghosium-source-installer-smoke-$PID"
$runtimeProfile = Join-Path $smokeRoot 'runtime-profile'
$runtimeStdout = Join-Path $smokeRoot 'runtime.stdout.txt'
$runtimeStderr = Join-Path $smokeRoot 'runtime.stderr.txt'
$installLog = Join-Path $smokeRoot 'install.log'
$uninstallLog = Join-Path $smokeRoot 'uninstall.log'
$pathTrimCharacters = [char[]]@('\', '/')
$expectedBrowserExecutable = 'Ghosium-Browser.exe'
$installedLicensePath = Join-Path $installRoot 'GHOSIUM-LICENSE.txt'
$installedNoticesPath = Join-Path $installRoot 'THIRD_PARTY_NOTICES.md'

New-Item -ItemType Directory -Force -Path $smokeRoot | Out-Null

function Get-GhosiumUninstallEntries {
  if (!(Test-Path $uninstallRoot)) {
    return @()
  }

  return @(
    Get-ChildItem $uninstallRoot -ErrorAction SilentlyContinue |
      ForEach-Object {
        $property = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
        if ($property) {
          $displayNameProperty = $property.PSObject.Properties['DisplayName']
          if ($displayNameProperty -and [string]$displayNameProperty.Value -eq 'Ghosium Browser') {
            [pscustomobject]@{
              KeyPath = $_.PSPath
              KeyName = $_.PSChildName
              Property = $property
            }
          }
        }
      }
  )
}

function Get-LogTail {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (!(Test-Path $Path -PathType Leaf)) {
    return '(installer log was not created)'
  }
  return ((Get-Content $Path -Tail 80 -ErrorAction SilentlyContinue) -join [Environment]::NewLine)
}

function Start-ProcessWithTimeout {
  param(
    [Parameter(Mandatory = $true)][string]$FilePath,
    [Parameter(Mandatory = $true)][string[]]$ArgumentList,
    [Parameter(Mandatory = $true)][int]$TimeoutSeconds,
    [Parameter(Mandatory = $true)][string]$Description,
    [Parameter(Mandatory = $false)][string]$RedirectStandardOutput,
    [Parameter(Mandatory = $false)][string]$RedirectStandardError
  )

  $startParams = @{
    FilePath = $FilePath
    ArgumentList = $ArgumentList
    PassThru = $true
  }
  if ($RedirectStandardOutput) {
    $startParams.RedirectStandardOutput = $RedirectStandardOutput
  }
  if ($RedirectStandardError) {
    $startParams.RedirectStandardError = $RedirectStandardError
  }

  $process = Start-Process @startParams
  if (!$process.WaitForExit($TimeoutSeconds * 1000)) {
    try {
      Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    } catch {
      Write-Warning "Unable to terminate timed-out process $($process.Id): $($_.Exception.Message)"
    }
    throw "$Description timed out after $TimeoutSeconds seconds."
  }
  return $process
}

function Wait-UntilRemoved {
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
    Start-Sleep -Milliseconds 500
  }
  throw "Timed out waiting for cleanup: $Description"
}

function Find-InstalledSetup {
  if (!(Test-Path $installRoot -PathType Container)) {
    return $null
  }

  $candidates = @(
    Get-ChildItem $installRoot -Recurse -File -Filter 'setup.exe' -ErrorAction SilentlyContinue |
      Where-Object { $_.Directory -and $_.Directory.Name -eq 'Installer' }
  )
  if ($candidates.Count -eq 0) {
    return $null
  }
  return $candidates | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
}

$preexistingEntries = @(Get-GhosiumUninstallEntries)
if (Test-Path $installRoot -PathType Container) {
  throw "Refusing destructive source-installer smoke because a Ghosium installation already exists: $installRoot"
}
if (Test-Path $defaultUserDataRoot -PathType Container) {
  throw "Refusing destructive source-installer smoke because Ghosium user data already exists: $defaultUserDataRoot"
}
if ($preexistingEntries.Count -gt 0) {
  throw "Refusing destructive source-installer smoke because $($preexistingEntries.Count) Ghosium uninstall registration(s) already exist."
}

$installExitCode = $null
$uninstallExitCode = $null
$runtimeExitCode = $null
$runtimeSmokePassed = $false
$installedBrowserVersion = $null
$installedBrowserExecutableName = $null
$installedLicenseSha256 = $null
$installedNoticesSha256 = $null
$installedLegalPayloadVerified = $false
$uninstallRegistryKey = $null
$cleanupAttempted = $false
$completed = $false

try {
  # The upstream mini-installer machinery remains a technical build dependency.
  # Keep this a per-user install so the smoke does not require elevation on the
  # dedicated self-hosted builder. Prevent any first-install browser launch.
  $installArguments = @(
    '--verbose-logging',
    '--do-not-launch-chrome',
    '--do-not-register-for-update-launch',
    "--log-file=`"$installLog`""
  )
  $install = Start-ProcessWithTimeout `
    -FilePath $miniInstaller `
    -ArgumentList $installArguments `
    -TimeoutSeconds 180 `
    -Description 'Source-built Ghosium mini_installer'
  $installExitCode = $install.ExitCode
  if ($installExitCode -ne 0) {
    throw "Source-built Ghosium mini_installer failed with exit code $installExitCode.`n$(Get-LogTail -Path $installLog)"
  }

  if (!(Test-Path $installRoot -PathType Container)) {
    throw "Source-built installer did not create the expected Ghosium application directory: $installRoot`n$(Get-LogTail -Path $installLog)"
  }

  # Public binary identity is a release invariant. A build that still installs
  # chrome.exe may be useful for source-patch testing, but it is not releasable
  # as Ghosium 0.1.0.
  $browserCandidates = @(
    Get-ChildItem $installRoot -Recurse -File -Filter $expectedBrowserExecutable -ErrorAction SilentlyContinue
  )
  if ($browserCandidates.Count -ne 1) {
    $legacyChrome = @(
      Get-ChildItem $installRoot -Recurse -File -Filter 'chrome.exe' -ErrorAction SilentlyContinue
    )
    $legacyHint = if ($legacyChrome.Count -gt 0) {
      " Found $($legacyChrome.Count) legacy chrome.exe binary/binaries instead."
    } else {
      ''
    }
    throw "Installed source-built Ghosium executable identity is incomplete: expected exactly one $expectedBrowserExecutable under $installRoot; found $($browserCandidates.Count).$legacyHint"
  }

  $installedBrowser = $browserCandidates[0]
  $installedBrowserExecutableName = $installedBrowser.Name
  if ($installedBrowserExecutableName -cne $expectedBrowserExecutable) {
    throw "Installed browser executable name mismatch: '$installedBrowserExecutableName'"
  }

  $browserInfo = $installedBrowser.VersionInfo
  if ([string]$browserInfo.ProductName -ne 'Ghosium Browser') {
    throw "Installed $expectedBrowserExecutable ProductName mismatch: '$($browserInfo.ProductName)'"
  }
  if ([string]$browserInfo.CompanyName -ne 'Brendigo') {
    throw "Installed $expectedBrowserExecutable CompanyName mismatch: '$($browserInfo.CompanyName)'"
  }
  if (!$browserInfo.ProductVersion) {
    throw "Installed $expectedBrowserExecutable ProductVersion is empty."
  }
  $installedBrowserVersion = [string]$browserInfo.ProductVersion

  # Legal material must be part of the actual installed application, not only
  # a detached GitHub release attachment. Require byte-identical copies of the
  # reviewed repository license and third-party notices.
  foreach ($installedLegal in @($installedLicensePath, $installedNoticesPath)) {
    if (!(Test-Path $installedLegal -PathType Leaf)) {
      throw "Installed Ghosium legal payload is missing: $installedLegal"
    }
  }
  $installedLicenseSha256 = (Get-FileHash $installedLicensePath -Algorithm SHA256).Hash.ToLowerInvariant()
  $installedNoticesSha256 = (Get-FileHash $installedNoticesPath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($installedLicenseSha256 -ne $expectedLicenseSha256) {
    throw 'Installed GHOSIUM-LICENSE.txt does not match repository LICENSE.'
  }
  if ($installedNoticesSha256 -ne $expectedNoticesSha256) {
    throw 'Installed THIRD_PARTY_NOTICES.md does not match repository notices.'
  }
  $installedLicenseText = Get-Content $installedLicensePath -Raw
  if (!$installedLicenseText.Contains('Proprietary Commercial Software License Agreement') -or
      !$installedLicenseText.Contains('Open-source components remain governed by their respective licenses.')) {
    throw 'Installed Ghosium license lost the proprietary-product or third-party-rights contract.'
  }
  $installedLegalPayloadVerified = $true

  $entries = @(Get-GhosiumUninstallEntries)
  if ($entries.Count -ne 1) {
    throw "Expected exactly one Ghosium Browser uninstall registration after installation; found $($entries.Count)."
  }
  $entry = $entries[0]
  $uninstallRegistryKey = [string]$entry.KeyName
  $reg = $entry.Property
  $uninstallStringProperty = $reg.PSObject.Properties['UninstallString']
  if (!$uninstallStringProperty -or ![string]$uninstallStringProperty.Value) {
    throw 'Installed Ghosium uninstall registration is missing UninstallString.'
  }
  $uninstallString = [string]$uninstallStringProperty.Value
  if ($uninstallString -notmatch '(?i)setup\.exe' -or $uninstallString -notmatch '(?i)--uninstall') {
    throw "Installed Ghosium UninstallString is not setup.exe --uninstall based: '$uninstallString'"
  }

  $installLocationProperty = $reg.PSObject.Properties['InstallLocation']
  if ($installLocationProperty -and [string]$installLocationProperty.Value) {
    $registeredInstall = [IO.Path]::GetFullPath([string]$installLocationProperty.Value).TrimEnd($pathTrimCharacters)
    $expectedInstall = [IO.Path]::GetFullPath($installRoot).TrimEnd($pathTrimCharacters)
    if ($registeredInstall -ne $expectedInstall) {
      throw "Installed Ghosium InstallLocation mismatch: '$($installLocationProperty.Value)'"
    }
  }

  $installedSetup = Find-InstalledSetup
  if (!$installedSetup) {
    throw "Installed source-built setup.exe was not found under $installRoot"
  }
  if ($uninstallString -notlike "*$($installedSetup.Name)*") {
    throw "UninstallString does not reference the installed setup executable: '$uninstallString'"
  }

  # Exercise the installed layout, not the loose build-tree executable. This
  # catches missing DLL/resource/install-layout problems that a pre-install
  # runtime smoke cannot detect.
  $runtimeArguments = @(
    '--headless=new',
    '--disable-gpu',
    '--disable-sync',
    '--no-pings',
    '--no-first-run',
    "--user-data-dir=`"$runtimeProfile`"",
    '--dump-dom',
    'data:text/html,<html><body>ghosium-source-installed-runtime-ok</body></html>'
  )
  $runtime = Start-ProcessWithTimeout `
    -FilePath $installedBrowser.FullName `
    -ArgumentList $runtimeArguments `
    -TimeoutSeconds 60 `
    -Description 'Installed source-built Ghosium runtime smoke' `
    -RedirectStandardOutput $runtimeStdout `
    -RedirectStandardError $runtimeStderr
  $runtimeExitCode = $runtime.ExitCode
  $runtimeOutput = if (Test-Path $runtimeStdout -PathType Leaf) { Get-Content $runtimeStdout -Raw } else { '' }
  $runtimeError = if (Test-Path $runtimeStderr -PathType Leaf) { Get-Content $runtimeStderr -Raw } else { '' }
  if ($runtimeExitCode -ne 0 -or !$runtimeOutput.Contains('ghosium-source-installed-runtime-ok')) {
    Write-Host $runtimeOutput
    Write-Host $runtimeError
    throw "Installed source-built Ghosium runtime smoke failed with exit code $runtimeExitCode."
  }
  $runtimeSmokePassed = $true

  $uninstallArguments = @(
    '--uninstall',
    '--force-uninstall',
    '--delete-profile',
    '--verbose-logging',
    "--log-file=`"$uninstallLog`""
  )
  $remove = Start-ProcessWithTimeout `
    -FilePath $installedSetup.FullName `
    -ArgumentList $uninstallArguments `
    -TimeoutSeconds 120 `
    -Description 'Installed Ghosium setup.exe uninstall'
  $uninstallExitCode = $remove.ExitCode
  if ($uninstallExitCode -ne 0) {
    throw "Installed Ghosium setup.exe uninstall failed with exit code $uninstallExitCode.`n$(Get-LogTail -Path $uninstallLog)"
  }

  Wait-UntilRemoved `
    -Condition { !(Test-Path $installRoot) -and @(Get-GhosiumUninstallEntries).Count -eq 0 } `
    -TimeoutSeconds 60 `
    -Description 'Ghosium application directory and uninstall registration'

  if (Test-Path $defaultUserDataRoot) {
    throw "Default Ghosium user-data directory remains after --delete-profile uninstall: $defaultUserDataRoot"
  }
  if ((Test-Path $installedLicensePath -PathType Leaf) -or (Test-Path $installedNoticesPath -PathType Leaf)) {
    throw 'Installed Ghosium legal payload remains after application uninstall.'
  }

  if (!$ReportPath) {
    $ReportPath = Join-Path (Get-Location).Path 'GHOSIUM-SOURCE-INSTALLER-SMOKE.json'
  } elseif (![IO.Path]::IsPathRooted($ReportPath)) {
    $ReportPath = [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $ReportPath))
  }
  $reportDirectory = Split-Path -Parent $ReportPath
  if ($reportDirectory) {
    New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
  }

  [ordered]@{
    schemaVersion = 3
    product = 'Ghosium Browser'
    architecture = 'windows-x64'
    installMode = 'per-user'
    miniInstallerSha256 = (Get-FileHash $miniInstaller -Algorithm SHA256).Hash.ToLowerInvariant()
    installedBrowserExecutableName = $installedBrowserExecutableName
    publicExecutableIdentityComplete = $installedBrowserExecutableName -ceq $expectedBrowserExecutable
    installedBrowserProductVersion = $installedBrowserVersion
    installedBrowserProductName = 'Ghosium Browser'
    publisher = 'Brendigo'
    legalPayload = [ordered]@{
      installed = $installedLegalPayloadVerified
      productLicense = 'Brendigo Proprietary Commercial Software License Agreement'
      agreementVersion = '1.0'
      licenseSha256 = $installedLicenseSha256
      thirdPartyNoticesSha256 = $installedNoticesSha256
      matchesRepository = ($installedLicenseSha256 -eq $expectedLicenseSha256 -and $installedNoticesSha256 -eq $expectedNoticesSha256)
      removedWithApplication = (!(Test-Path $installedLicensePath) -and !(Test-Path $installedNoticesPath))
      thirdPartyLicensesPreserved = $true
    }
    uninstallRegistryKey = $uninstallRegistryKey
    installExitCode = $installExitCode
    installedRuntimeSmoke = [ordered]@{
      passed = $runtimeSmokePassed
      exitCode = $runtimeExitCode
      timeoutSeconds = 60
      sandboxDisabled = $false
      isolatedProfile = $true
    }
    uninstall = [ordered]@{
      setupBased = $true
      forceUninstall = $true
      deleteProfile = $true
      exitCode = $uninstallExitCode
      timeoutSeconds = 120
      applicationDirectoryRemoved = !(Test-Path $installRoot)
      registrationRemoved = @(Get-GhosiumUninstallEntries).Count -eq 0
      defaultUserDataRemoved = !(Test-Path $defaultUserDataRoot)
    }
    repositoryCommit = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } else { $null }
    verifiedUtc = [DateTime]::UtcNow.ToString('o')
  } | ConvertTo-Json -Depth 6 | Set-Content $ReportPath -Encoding utf8

  $completed = $true
  Write-Host 'Source-built Ghosium mini_installer -> installed Ghosium runtime/legal payload -> registered setup.exe uninstall smoke test: OK'
  Write-Host "Installed Ghosium executable: $installedBrowserExecutableName"
  Write-Host "Installed browser file version: $installedBrowserVersion"
  Write-Host 'Installed legal payload: repository-identical Ghosium license + third-party notices'
  Write-Host "Installer smoke provenance: $ReportPath"
}
finally {
  if (!$completed -and (Test-Path $installRoot -PathType Container)) {
    $cleanupSetup = Find-InstalledSetup
    if ($cleanupSetup) {
      $cleanupAttempted = $true
      try {
        [void](Start-ProcessWithTimeout `
          -FilePath $cleanupSetup.FullName `
          -ArgumentList @('--uninstall', '--force-uninstall', '--delete-profile') `
          -TimeoutSeconds 120 `
          -Description 'Best-effort Ghosium cleanup uninstall')
      } catch {
        Write-Warning "Best-effort Ghosium cleanup failed after installer smoke error: $($_.Exception.Message)"
      }
    }
  }

  if (!$completed -and $cleanupAttempted) {
    Write-Host 'Best-effort source-installer cleanup was attempted after smoke-test failure.'
  }
  Remove-Item $runtimeProfile -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item $smokeRoot -Recurse -Force -ErrorAction SilentlyContinue
}
