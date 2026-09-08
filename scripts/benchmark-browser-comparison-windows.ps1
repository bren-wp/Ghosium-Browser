param(
  [Parameter(Mandatory = $true)][string]$GhosiumPath,
  [Parameter(Mandatory = $true)][string]$OutputPath,
  [int]$StartupTimeoutSeconds = 30,
  [int]$SettleSeconds = 5
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-FirstFile {
  param([string[]]$Candidates)
  foreach ($candidate in $Candidates) {
    if ([string]::IsNullOrWhiteSpace($candidate)) { continue }
    $expanded = [Environment]::ExpandEnvironmentVariables($candidate)
    if (Test-Path $expanded -PathType Leaf) { return (Resolve-Path $expanded).Path }
  }
  return $null
}

$definitions = @(
  [ordered]@{ name='Ghosium Browser'; process='Ghosium-Browser'; path=(Resolve-FirstFile @($GhosiumPath)); family='chromium' },
  [ordered]@{ name='Google Chrome'; process='chrome'; path=(Resolve-FirstFile @('%ProgramFiles%\Google\Chrome\Application\chrome.exe','%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe')); family='chromium' },
  [ordered]@{ name='Microsoft Edge'; process='msedge'; path=(Resolve-FirstFile @('%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe','%ProgramFiles%\Microsoft\Edge\Application\msedge.exe')); family='chromium' },
  [ordered]@{ name='Mozilla Firefox'; process='firefox'; path=(Resolve-FirstFile @('%ProgramFiles%\Mozilla Firefox\firefox.exe','%ProgramFiles(x86)%\Mozilla Firefox\firefox.exe')); family='firefox' },
  [ordered]@{ name='Brave'; process='brave'; path=(Resolve-FirstFile @('%ProgramFiles%\BraveSoftware\Brave-Browser\Application\brave.exe','%LOCALAPPDATA%\BraveSoftware\Brave-Browser\Application\brave.exe')); family='chromium' },
  [ordered]@{ name='Vivaldi'; process='vivaldi'; path=(Resolve-FirstFile @('%LOCALAPPDATA%\Vivaldi\Application\vivaldi.exe','%ProgramFiles%\Vivaldi\Application\vivaldi.exe')); family='chromium' },
  [ordered]@{ name='Opera'; process='opera'; path=(Resolve-FirstFile @('%LOCALAPPDATA%\Programs\Opera\opera.exe','%LOCALAPPDATA%\Programs\Opera GX\opera.exe','%ProgramFiles%\Opera\opera.exe')); family='chromium' }
)

function Stop-Browser {
  param([string]$ProcessName)
  Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | ForEach-Object {
    try { Stop-Process -Id $_.Id -Force -ErrorAction Stop } catch {}
  }
  Start-Sleep -Milliseconds 500
}

function Get-BrowserProcesses {
  param([string]$ProcessName)
  @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)
}

function Wait-Window {
  param([string]$ProcessName,[Diagnostics.Stopwatch]$Watch)
  $deadline = [DateTime]::UtcNow.AddSeconds($StartupTimeoutSeconds)
  while ([DateTime]::UtcNow -lt $deadline) {
    $window = Get-BrowserProcesses $ProcessName | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if ($window) { return [int64]$Watch.ElapsedMilliseconds }
    Start-Sleep -Milliseconds 50
  }
  throw "$ProcessName did not expose a usable window within $StartupTimeoutSeconds seconds."
}

function Get-Sample {
  param([string]$ProcessName)
  $processes = @(Get-BrowserProcesses $ProcessName)
  [ordered]@{
    processCount = $processes.Count
    workingSetBytes = [uint64](($processes | Measure-Object WorkingSet64 -Sum).Sum)
    privateMemoryBytes = [uint64](($processes | Measure-Object PrivateMemorySize64 -Sum).Sum)
    handleCount = [int](($processes | Measure-Object HandleCount -Sum).Sum)
    cpuSeconds = [double](($processes | Measure-Object CPU -Sum).Sum)
  }
}

function Invoke-Scenario {
  param($Browser,[int]$Tabs,[string]$ProfileRoot)
  Stop-Browser $Browser.process
  if (Test-Path $ProfileRoot) { Remove-Item $ProfileRoot -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $ProfileRoot | Out-Null

  $page = 'data:text/html,<title>Ghosium%20Benchmark</title><main>Browser%20comparison</main>'
  $urls = @(); for ($i=0; $i -lt $Tabs; $i++) { $urls += $page }
  $args = if ($Browser.family -eq 'firefox') {
    @('-no-remote','-profile',$ProfileRoot) + $urls
  } else {
    @("--user-data-dir=$ProfileRoot",'--no-first-run','--no-default-browser-check','--disable-background-mode') + $urls
  }

  $watch = [Diagnostics.Stopwatch]::StartNew()
  $started = Start-Process -FilePath $Browser.path -ArgumentList $args -PassThru
  $startupMs = Wait-Window -ProcessName $Browser.process -Watch $watch
  Start-Sleep -Seconds $SettleSeconds
  $sample1 = Get-Sample $Browser.process
  Start-Sleep -Seconds 2
  $sample2 = Get-Sample $Browser.process
  $logical = [Math]::Max(1,[Environment]::ProcessorCount)
  $cpuDelta = [Math]::Max(0.0,[double]$sample2.cpuSeconds-[double]$sample1.cpuSeconds)
  $cpuPercent = [Math]::Round(($cpuDelta/(2*$logical))*100,3)

  Stop-Browser $Browser.process
  [ordered]@{
    tabs = $Tabs
    firstUsableWindowMs = $startupMs
    settleSeconds = $SettleSeconds
    processCount = $sample2.processCount
    workingSetBytes = $sample2.workingSetBytes
    privateMemoryBytes = $sample2.privateMemoryBytes
    handleCount = $sample2.handleCount
    normalizedCpuPercent = $cpuPercent
  }
}

$root = Join-Path $env:RUNNER_TEMP ('browser-comparison-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $root | Out-Null
$results = @()
try {
  foreach ($browser in $definitions) {
    if (!$browser.path) {
      $results += [ordered]@{ name=$browser.name; available=$false; reason='Executable not installed on benchmark host.' }
      continue
    }
    $file = Get-Item $browser.path
    $version = $file.VersionInfo.ProductVersion
    $sha = (Get-FileHash $browser.path -Algorithm SHA256).Hash.ToLowerInvariant()
    $scenarios = @()
    try {
      foreach ($tabs in @(1,5,10)) {
        $profile = Join-Path $root (($browser.name -replace '[^A-Za-z0-9]+','-') + "-$tabs")
        $scenarios += Invoke-Scenario -Browser $browser -Tabs $tabs -ProfileRoot $profile
      }
      $results += [ordered]@{ name=$browser.name; available=$true; path=$browser.path; productVersion=$version; executableSha256=$sha; scenarios=$scenarios }
    } catch {
      Stop-Browser $browser.process
      $results += [ordered]@{ name=$browser.name; available=$false; path=$browser.path; productVersion=$version; executableSha256=$sha; reason=$_.Exception.Message }
    }
  }
} finally {
  foreach ($browser in $definitions) { Stop-Browser $browser.process }
  Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
}

$report = [ordered]@{
  schemaVersion = 1
  capturedAtUtc = [DateTime]::UtcNow.ToString('o')
  host = [ordered]@{
    os = [Environment]::OSVersion.VersionString
    logicalProcessors = [Environment]::ProcessorCount
    machineName = $env:COMPUTERNAME
  }
  methodology = [ordered]@{
    freshProfilePerScenario = $true
    tabs = @(1,5,10)
    page = 'local data: URL; no network benchmark content'
    startupMetric = 'milliseconds to first usable top-level window'
    resourceSampleAfterSeconds = $SettleSeconds
    cpuIntervalSeconds = 2
  }
  browsers = $results
}

$fullOutput = [IO.Path]::GetFullPath($OutputPath)
$dir = Split-Path -Parent $fullOutput
if ($dir -and !(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[IO.File]::WriteAllText($fullOutput,(($report | ConvertTo-Json -Depth 10)+"`n"),[Text.UTF8Encoding]::new($false))
Write-Host "Browser comparison evidence written: $fullOutput"
