param(
  [Parameter(Mandatory = $true)]
  [string]$BrowserPath,

  [Parameter(Mandatory = $true)]
  [string]$OutputPath,

  [int]$IdleSeconds = 60,
  [int]$StartupTimeoutSeconds = 30,
  [string]$ProfileRoot = "$env:RUNNER_TEMP\ghosium-performance-profile",
  [string]$PageUrl = 'https://example.com/',

  [ValidateSet('PortableProfile', 'UserDataDir')]
  [string]$ProfileMode = 'PortableProfile'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$script:BenchmarkRootProcessIds = [System.Collections.Generic.HashSet[int]]::new()

if ($IdleSeconds -lt 1 -or $StartupTimeoutSeconds -lt 1) {
  throw 'Benchmark idle/startup timeout values must be positive.'
}

function Get-GhosiumProcesses {
  $result = [System.Collections.Generic.List[object]]::new()
  foreach ($name in @('Ghosium-Browser', 'Ghosium-Engine')) {
    foreach ($process in @(Get-Process -Name $name -ErrorAction SilentlyContinue)) {
      $result.Add($process)
    }
  }
  @($result)
}

function Assert-NoPreExistingGhosium {
  $existing = @(Get-GhosiumProcesses)
  if ($existing.Count -gt 0) {
    $details = ($existing | Sort-Object Id | ForEach-Object { "$($_.ProcessName):$($_.Id)" }) -join ', '
    throw "Refusing to benchmark while a pre-existing Ghosium session is running: $details. The benchmark never terminates user-owned Ghosium processes."
  }
}

function Register-BenchmarkProcess {
  param([Parameter(Mandatory = $true)][System.Diagnostics.Process]$Process)
  [void]$script:BenchmarkRootProcessIds.Add([int]$Process.Id)
}

function Stop-BenchmarkOwnedProcesses {
  if ($script:BenchmarkRootProcessIds.Count -eq 0) {
    return
  }

  $roots = @($script:BenchmarkRootProcessIds)
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

    $owned = [System.Collections.Generic.HashSet[int]]::new()
    $stack = [System.Collections.Generic.Stack[int]]::new()
    foreach ($root in $roots) { $stack.Push($root) }
    while ($stack.Count -gt 0) {
      $current = $stack.Pop()
      if (!$owned.Add($current)) { continue }
      if ($children.ContainsKey($current)) {
        foreach ($child in $children[$current]) { $stack.Push($child) }
      }
    }

    # Kill descendants before launch roots so child processes cannot survive a
    # browser shutdown race. Scope is process-tree ownership, never image name.
    $depth = @{}
    foreach ($root in $roots) { $depth[$root] = 0 }
    $queue = [System.Collections.Generic.Queue[int]]::new()
    foreach ($root in $roots) { $queue.Enqueue($root) }
    while ($queue.Count -gt 0) {
      $current = $queue.Dequeue()
      if (!$children.ContainsKey($current)) { continue }
      foreach ($child in $children[$current]) {
        if ($owned.Contains($child) -and !$depth.ContainsKey($child)) {
          $depth[$child] = [int]$depth[$current] + 1
          $queue.Enqueue($child)
        }
      }
    }

    foreach ($processId in @($owned) | Sort-Object { if ($depth.ContainsKey($_)) { $depth[$_] } else { 0 } } -Descending) {
      try {
        Stop-Process -Id $processId -Force -ErrorAction Stop
      } catch {
        Write-Verbose "Benchmark-owned process $processId already exited or could not be stopped: $($_.Exception.Message)"
      }
    }
  } catch {
    Write-Verbose "Unable to enumerate benchmark process tree; falling back to exact launcher PIDs only: $($_.Exception.Message)"
    foreach ($processId in $roots) {
      try {
        Stop-Process -Id $processId -Force -ErrorAction Stop
      } catch {
        Write-Verbose "Benchmark launcher $processId already exited: $($_.Exception.Message)"
      }
    }
  } finally {
    $script:BenchmarkRootProcessIds.Clear()
  }

  Start-Sleep -Milliseconds 500
}

function Assert-GhosiumStopped {
  $remaining = @(Get-GhosiumProcesses)
  if ($remaining.Count -gt 0) {
    $details = ($remaining | Sort-Object Id | ForEach-Object { "$($_.ProcessName):$($_.Id)" }) -join ', '
    throw "Benchmark-owned Ghosium process tree did not terminate cleanly: $details"
  }
}

function Reset-BenchmarkProcesses {
  Stop-BenchmarkOwnedProcesses
  Assert-GhosiumStopped
}

function Get-ProcessIoTotals {
  param([int[]]$ProcessIds)

  [uint64]$readBytes = 0
  [uint64]$writeBytes = 0
  foreach ($processId in $ProcessIds) {
    try {
      $process = Get-CimInstance Win32_Process -Filter "ProcessId = $processId" -ErrorAction Stop
      if ($null -ne $process) {
        $readBytes += [uint64]$process.ReadTransferCount
        $writeBytes += [uint64]$process.WriteTransferCount
      }
    } catch {
      # A browser subprocess can legitimately exit between enumeration and the
      # CIM sample. The benchmark records the surviving process set.
    }
  }

  [ordered]@{
    readBytes = $readBytes
    writeBytes = $writeBytes
  }
}

function Get-NetworkSnapshot {
  param([int[]]$ProcessIds)

  if ($ProcessIds.Count -eq 0) {
    return [ordered]@{
      available = $true
      tcpConnections = 0
      establishedTcpConnections = 0
      tcpStates = [ordered]@{}
      udpEndpoints = 0
      uniqueRemoteAddressCount = 0
    }
  }
  if (!(Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue)) {
    return [ordered]@{
      available = $false
      reason = 'Get-NetTCPConnection is unavailable on this Windows host.'
    }
  }

  try {
    $pidSet = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($processId in $ProcessIds) { [void]$pidSet.Add($processId) }
    $tcp = @(Get-NetTCPConnection -ErrorAction Stop | Where-Object {
      $pidSet.Contains([int]$_.OwningProcess)
    })
    $udp = @()
    if (Get-Command Get-NetUDPEndpoint -ErrorAction SilentlyContinue) {
      $udp = @(Get-NetUDPEndpoint -ErrorAction Stop | Where-Object {
        $pidSet.Contains([int]$_.OwningProcess)
      })
    }

    $states = [ordered]@{}
    foreach ($connection in $tcp) {
      $state = [string]$connection.State
      if (!$states.Contains($state)) { $states[$state] = 0 }
      $states[$state] = [int]$states[$state] + 1
    }

    $remoteAddresses = @($tcp | Where-Object {
      $_.State -notin @('Listen', 'Closed') -and
      $_.RemoteAddress -and
      $_.RemoteAddress -notin @('0.0.0.0', '::', '127.0.0.1', '::1')
    } | ForEach-Object { [string]$_.RemoteAddress } | Sort-Object -Unique)

    return [ordered]@{
      available = $true
      tcpConnections = $tcp.Count
      establishedTcpConnections = @($tcp | Where-Object { $_.State -eq 'Established' }).Count
      tcpStates = $states
      udpEndpoints = $udp.Count
      uniqueRemoteAddressCount = $remoteAddresses.Count
    }
  } catch {
    return [ordered]@{
      available = $false
      reason = $_.Exception.Message
    }
  }
}

function Get-GpuMemorySnapshot {
  param([int[]]$ProcessIds)

  if ($ProcessIds.Count -eq 0) {
    return [ordered]@{
      available = $true
      matchedSampleCount = 0
      localUsageBytes = 0
      nonLocalUsageBytes = 0
      totalCommittedBytes = 0
    }
  }
  if (!(Get-Command Get-Counter -ErrorAction SilentlyContinue)) {
    return [ordered]@{
      available = $false
      reason = 'Get-Counter is unavailable on this Windows host.'
    }
  }

  try {
    $counterSet = Get-Counter -ListSet 'GPU Process Memory' -ErrorAction Stop
    $counterPaths = @($counterSet.PathsWithInstances | Where-Object {
      $_ -match '\\(Local Usage|Non Local Usage|Total Committed)$'
    })
    if ($counterPaths.Count -eq 0) {
      return [ordered]@{
        available = $false
        reason = 'GPU Process Memory counters are not exposed by this host/driver.'
      }
    }

    $pidSet = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($processId in $ProcessIds) { [void]$pidSet.Add($processId) }
    $samples = @(Get-Counter -Counter $counterPaths -ErrorAction Stop).CounterSamples
    [uint64]$localUsage = 0
    [uint64]$nonLocalUsage = 0
    [uint64]$totalCommitted = 0
    $matched = 0
    $localSeen = $false
    $nonLocalSeen = $false
    $committedSeen = $false

    foreach ($sample in $samples) {
      $match = [regex]::Match([string]$sample.InstanceName, '(?i)^pid_(\d+)_')
      if (!$match.Success) { continue }
      $pidValue = [int]$match.Groups[1].Value
      if (!$pidSet.Contains($pidValue)) { continue }

      $matched++
      [uint64]$value = [uint64][math]::Max(0, [double]$sample.CookedValue)
      $path = ([string]$sample.Path).ToLowerInvariant()
      if ($path.EndsWith('\local usage')) {
        $localUsage += $value
        $localSeen = $true
      } elseif ($path.EndsWith('\non local usage')) {
        $nonLocalUsage += $value
        $nonLocalSeen = $true
      } elseif ($path.EndsWith('\total committed')) {
        $totalCommitted += $value
        $committedSeen = $true
      }
    }

    return [ordered]@{
      available = $true
      matchedSampleCount = $matched
      localUsageBytes = $(if ($localSeen) { $localUsage } else { $null })
      nonLocalUsageBytes = $(if ($nonLocalSeen) { $nonLocalUsage } else { $null })
      totalCommittedBytes = $(if ($committedSeen) { $totalCommitted } else { $null })
    }
  } catch {
    return [ordered]@{
      available = $false
      reason = $_.Exception.Message
    }
  }
}

function Get-BrowserSample {
  $processes = @(Get-GhosiumProcesses)
  $ids = @($processes | ForEach-Object { $_.Id })
  $io = Get-ProcessIoTotals -ProcessIds $ids

  [ordered]@{
    capturedAtUtc = [DateTime]::UtcNow.ToString('o')
    processCount = $processes.Count
    processIds = $ids
    workingSetBytes = [uint64](($processes | Measure-Object WorkingSet64 -Sum).Sum)
    privateMemoryBytes = [uint64](($processes | Measure-Object PrivateMemorySize64 -Sum).Sum)
    pagedMemoryBytes = [uint64](($processes | Measure-Object PagedMemorySize64 -Sum).Sum)
    handleCount = [int](($processes | Measure-Object HandleCount -Sum).Sum)
    cpuSeconds = [double](($processes | Measure-Object CPU -Sum).Sum)
    ioReadBytes = [uint64]$io.readBytes
    ioWriteBytes = [uint64]$io.writeBytes
    gpuMemory = Get-GpuMemorySnapshot -ProcessIds $ids
    network = Get-NetworkSnapshot -ProcessIds $ids
  }
}

function Measure-ActivityInterval {
  param([int]$Seconds)

  $first = Get-BrowserSample
  Start-Sleep -Seconds $Seconds
  $second = Get-BrowserSample
  $logicalProcessors = [Environment]::ProcessorCount
  $cpuDelta = [math]::Max(0.0, [double]$second.cpuSeconds - [double]$first.cpuSeconds)
  $capacity = [math]::Max(1.0, $Seconds * $logicalProcessors)

  [ordered]@{
    intervalSeconds = $Seconds
    cpuSecondsDelta = $cpuDelta
    normalizedCpuPercent = [math]::Round(($cpuDelta / $capacity) * 100.0, 3)
    ioReadBytesDelta = [uint64][math]::Max(0, [double]$second.ioReadBytes - [double]$first.ioReadBytes)
    ioWriteBytesDelta = [uint64][math]::Max(0, [double]$second.ioWriteBytes - [double]$first.ioWriteBytes)
    first = $first
    second = $second
  }
}

function Wait-ForUsableWindow {
  param([System.Diagnostics.Stopwatch]$Stopwatch)

  $deadline = [DateTime]::UtcNow.AddSeconds($StartupTimeoutSeconds)
  while ([DateTime]::UtcNow -lt $deadline) {
    $window = Get-GhosiumProcesses | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if ($null -ne $window) {
      return [ordered]@{
        firstUsableWindowMs = $Stopwatch.ElapsedMilliseconds
        processId = $window.Id
        processName = $window.ProcessName
      }
    }
    Start-Sleep -Milliseconds 50
  }

  throw "Ghosium did not expose a usable top-level window within $StartupTimeoutSeconds seconds."
}

function Start-Ghosium {
  param(
    [string]$ProfilePath,
    [string]$Url
  )

  $profileArgument = if ($ProfileMode -eq 'UserDataDir') {
    "--user-data-dir=$ProfilePath"
  } else {
    "--ghosium-portable-profile=$ProfilePath"
  }

  $arguments = @(
    $profileArgument,
    '--no-first-run',
    '--no-default-browser-check',
    $Url
  )

  $process = Start-Process -FilePath $BrowserPath -ArgumentList $arguments -PassThru
  Register-BenchmarkProcess -Process $process
  return $process
}

function Measure-Startup {
  param(
    [string]$ProfilePath,
    [bool]$FreshProfile,
    [string]$Label
  )

  Reset-BenchmarkProcesses
  if ($FreshProfile -and (Test-Path $ProfilePath)) {
    Remove-Item $ProfilePath -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $ProfilePath | Out-Null

  $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
  $launcher = Start-Ghosium -ProfilePath $ProfilePath -Url "${PageUrl}?ghosium-startup=$Label"
  $window = Wait-ForUsableWindow -Stopwatch $stopwatch
  $stopwatch.Stop()

  Start-Sleep -Seconds 2
  $sample = Get-BrowserSample

  [ordered]@{
    label = $Label
    initialProcessId = $launcher.Id
    launchToUsableWindowMs = $window.firstUsableWindowMs
    firstWindowProcessId = $window.processId
    firstWindowProcessName = $window.processName
    postStartupSample = $sample
  }
}

function Measure-TabScenario {
  param(
    [string]$ProfilePath,
    [int]$TabCount,
    [bool]$MeasureOneMinuteIdle
  )

  Reset-BenchmarkProcesses
  if (Test-Path $ProfilePath) {
    Remove-Item $ProfilePath -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $ProfilePath | Out-Null

  $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
  Start-Ghosium -ProfilePath $ProfilePath -Url "${PageUrl}?ghosium-tab=1" | Out-Null
  $window = Wait-ForUsableWindow -Stopwatch $stopwatch
  $stopwatch.Stop()

  for ($index = 2; $index -le $TabCount; $index++) {
    Start-Ghosium -ProfilePath $ProfilePath -Url "${PageUrl}?ghosium-tab=$index" | Out-Null
    Start-Sleep -Milliseconds 250
  }

  Start-Sleep -Seconds 3
  $settled = Get-BrowserSample
  $shortIdle = Measure-ActivityInterval -Seconds 5
  $longIdle = $null

  if ($MeasureOneMinuteIdle) {
    $longIdle = Measure-ActivityInterval -Seconds $IdleSeconds
  }

  [ordered]@{
    tabCount = $TabCount
    launchToUsableWindowMs = $window.firstUsableWindowMs
    settledSample = $settled
    shortIdleActivity = $shortIdle
    longIdleActivity = $longIdle
  }
}

$resolvedBrowser = (Resolve-Path $BrowserPath).Path
$BrowserPath = $resolvedBrowser
$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory) {
  New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
}

Assert-NoPreExistingGhosium
if (Test-Path $ProfileRoot) {
  Remove-Item $ProfileRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $ProfileRoot | Out-Null

try {
  $startupProfile = Join-Path $ProfileRoot 'startup'
  $cold = Measure-Startup -ProfilePath $startupProfile -FreshProfile $true -Label 'cold'
  Reset-BenchmarkProcesses
  $warm = Measure-Startup -ProfilePath $startupProfile -FreshProfile $false -Label 'warm'

  $oneTab = Measure-TabScenario -ProfilePath (Join-Path $ProfileRoot 'tabs-1') -TabCount 1 -MeasureOneMinuteIdle $true
  $fiveTabs = Measure-TabScenario -ProfilePath (Join-Path $ProfileRoot 'tabs-5') -TabCount 5 -MeasureOneMinuteIdle $false
  $tenTabs = Measure-TabScenario -ProfilePath (Join-Path $ProfileRoot 'tabs-10') -TabCount 10 -MeasureOneMinuteIdle $false

  Reset-BenchmarkProcesses

  $result = [ordered]@{
    schemaVersion = 2
    capturedAtUtc = [DateTime]::UtcNow.ToString('o')
    browserPath = $BrowserPath
    profileMode = $ProfileMode
    host = [ordered]@{
      machineName = $env:COMPUTERNAME
      os = [Environment]::OSVersion.VersionString
      logicalProcessors = [Environment]::ProcessorCount
      totalPhysicalMemoryBytes = [uint64](Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    }
    methodology = [ordered]@{
      coldStartup = 'Fresh isolated profile and no running Ghosium processes. OS filesystem cache is not forcibly flushed.'
      warmStartup = 'Same isolated profile reopened after benchmark-owned browser process-tree cleanup. OS filesystem cache is left intact.'
      usableWindow = 'First Ghosium Browser or Ghosium Engine process exposing a non-zero MainWindowHandle.'
      tabPages = $PageUrl
      idleSeconds = $IdleSeconds
      processIsolation = 'Benchmark refuses pre-existing Ghosium sessions and only terminates process trees rooted at launchers created by this run.'
      gpuMemory = 'Best-effort per-process Windows GPU Process Memory counters. When the OS/driver does not expose a reliable mapping, available=false is recorded instead of zero.'
      network = 'Best-effort Ghosium-owned TCP/UDP endpoint snapshots, including state and unique remote-address counts. This is connection activity, not byte-level packet attribution.'
      processIo = 'ReadTransferCount/WriteTransferCount are process-wide I/O counters and are not presented as network-byte counters.'
    }
    startup = [ordered]@{
      cold = $cold
      warm = $warm
    }
    tabs = @($oneTab, $fiveTabs, $tenTabs)
  }

  $result | ConvertTo-Json -Depth 16 | Set-Content $OutputPath -Encoding utf8
  Write-Host "Ghosium benchmark written to $OutputPath"
} finally {
  Stop-BenchmarkOwnedProcesses
  Remove-Item $ProfileRoot -Recurse -Force -ErrorAction SilentlyContinue
}
