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

function Get-BrowserProcesses {
  param([Parameter(Mandatory = $true)][string]$ProcessName)
  @(Get-Process -Name $ProcessName -ErrorAction SilentlyContinue)
}

function Assert-BrowserIdle {
  param($Browser)
  $existing = @(Get-BrowserProcesses -ProcessName $Browser.process)
  if ($existing.Count -gt 0) {
    $ids = ($existing | ForEach-Object { $_.Id } | Sort-Object) -join ','
    throw "Refusing to benchmark $($Browser.name) while a pre-existing session is running (PID(s): $ids). Existing user browser processes are never terminated by this benchmark."
  }
}

function Stop-OwnedProcessTree {
  param([Parameter(Mandatory = $true)][int]$RootProcessId)

  # Build a single process-tree snapshot and terminate only descendants of the
  # process explicitly started by this benchmark. Never kill by image name.
  try {
    $snapshot = @(Get-CimInstance Win32_Process -ErrorAction Stop)
    $children = @{}
    foreach ($process in $snapshot) {
      $parent = [int]$process.ParentProcessId
      if (!$children.ContainsKey($parent)) {
        $children[$parent] = [System.Collections.Generic.List[int]]::new()
      }
      $children[$parent].Add([int]$process.ProcessId)
    }

    $owned = [System.Collections.Generic.List[int]]::new()
    $stack = [System.Collections.Generic.Stack[int]]::new()
    $stack.Push($RootProcessId)
    while ($stack.Count -gt 0) {
      $current = $stack.Pop()
      $owned.Add($current)
      if ($children.ContainsKey($current)) {
        foreach ($child in $children[$current]) {
          $stack.Push($child)
        }
      }
    }

    # Descendants first, root last.
    for ($index = $owned.Count - 1; $index -ge 0; $index--) {
      $processId = $owned[$index]
      try {
        Stop-Process -Id $processId -Force -ErrorAction Stop
      } catch {
        Write-Verbose "Benchmark-owned process $processId already exited or could not be stopped: $($_.Exception.Message)"
      }
    }
  } catch {
    # If CIM enumeration is unavailable, fall back only to the exact launcher
    # PID. Never broaden cleanup to every process sharing the browser name.
    Write-Verbose "Unable to enumerate benchmark process tree: $($_.Exception.Message)"
    try {
      Stop-Process -Id $RootProcessId -Force -ErrorAction Stop
    } catch {
      Write-Verbose "Benchmark launcher $RootProcessId already exited: $($_.Exception.Message)"
    }
  }
}

function Wait-Window {
  param([string]$ProcessName,[Diagnostics.Stopwatch]$Watch)
  $deadline = [DateTime]::UtcNow.AddSeconds($StartupTimeoutSeconds)
  while ([DateTime]::UtcNow -lt $deadline) {
    $window = Get-BrowserProcesses -ProcessName $ProcessName | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if ($window) { return [int64]$Watch.ElapsedMilliseconds }
    Start-Sleep -Milliseconds 50
  }
  throw "$ProcessName did not expose a usable window within $StartupTimeoutSeconds seconds."
}

function Get-Sample {
  param([string]$ProcessName)
  $processes = @(Get-BrowserProcesses -ProcessName $ProcessName)
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

  Assert-BrowserIdle -Browser $Browser
  if (Test-Path $ProfileRoot) { Remove-Item $ProfileRoot -Recurse -Force }
  New-Item -ItemType Directory -Force -Path $ProfileRoot | Out-Null

  $page = 'data:text/html,<title>Ghosium%20Benchmark</title><main>Browser%20comparison</main>'
  $urls = @(); for ($i=0; $i -lt $Tabs; $i++) { $urls += $page }
  $args = if ($Browser.family -eq 'firefox') {
    @('-no-remote','-profile',$ProfileRoot) + $urls
  } else {
    @("--user-data-dir=$ProfileRoot",'--no-first-run','--no-default-browser-check','--disable-background-mode') + $urls
  }

  $started = $null
  try {
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $started = Start-Process -FilePath $Browser.path -ArgumentList $args -PassThru
    $startupMs = Wait-Window -ProcessName $Browser.process -Watch $watch
    $watch.Stop()

    Start-Sleep -Seconds $SettleSeconds
    $sample1 = Get-Sample -ProcessName $Browser.process
    Start-Sleep -Seconds 2
    $sample2 = Get-Sample -ProcessName $Browser.process
    $logical = [Math]::Max(1,[Environment]::ProcessorCount)
    $cpuDelta = [Math]::Max(0.0,[double]$sample2.cpuSeconds-[double]$sample1.cpuSeconds)
    $cpuPercent = [Math]::Round(($cpuDelta/(2*$logical))*100,3)

    return [ordered]@{
      tabs = $Tabs
      firstUsableWindowMs = $startupMs
      settleSeconds = $SettleSeconds
      processCount = $sample2.processCount
      workingSetBytes = $sample2.workingSetBytes
      privateMemoryBytes = $sample2.privateMemoryBytes
      handleCount = $sample2.handleCount
      normalizedCpuPercent = $cpuPercent
    }
  } finally {
    if ($null -ne $started) {
      Stop-OwnedProcessTree -RootProcessId $started.Id
      Start-Sleep -Milliseconds 500
    }
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

    $preExisting = @(Get-BrowserProcesses -ProcessName $browser.process)
    if ($preExisting.Count -gt 0) {
      $ids = ($preExisting | ForEach-Object { $_.Id } | Sort-Object) -join ','
      $results += [ordered]@{
        name=$browser.name
        available=$false
        reason="Skipped because an existing user session is running (PID(s): $ids); benchmark never terminates pre-existing browser processes."
      }
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
        if ((Get-BrowserProcesses -ProcessName $browser.process).Count -gt 0) {
          throw "$($browser.name) benchmark-owned process tree did not terminate cleanly after the $tabs-tab scenario."
        }
      }
      $results += [ordered]@{ name=$browser.name; available=$true; path=$browser.path; productVersion=$version; executableSha256=$sha; scenarios=$scenarios }
    } catch {
      $results += [ordered]@{ name=$browser.name; available=$false; path=$browser.path; productVersion=$version; executableSha256=$sha; reason=$_.Exception.Message }
    }
  }
} finally {
  # Profile cleanup is best-effort. Process cleanup happens per scenario and is
  # scoped to the exact launcher process tree; this finalizer never kills by
  # browser image name.
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
    processIsolation = 'Pre-existing browser sessions are skipped; cleanup is restricted to the benchmark-owned launcher process tree.'
  }
  browsers = $results
}

$fullOutput = [IO.Path]::GetFullPath($OutputPath)
$dir = Split-Path -Parent $fullOutput
if ($dir -and !(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
[IO.File]::WriteAllText($fullOutput,(($report | ConvertTo-Json -Depth 10)+"`n"),[Text.UTF8Encoding]::new($false))
Write-Host "Browser comparison evidence written: $fullOutput"
