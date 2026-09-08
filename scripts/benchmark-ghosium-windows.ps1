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

function Get-GhosiumProcesses {
  @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessName -in @('Ghosium-Browser', 'Ghosium-Engine')
  })
}

function Stop-GhosiumProcesses {
  $processes = @(Get-GhosiumProcesses)
  foreach ($process in $processes) {
    try {
      Stop-Process -Id $process.Id -Force -ErrorAction Stop
    } catch {
      Write-Verbose "Process $($process.Id) already exited: $($_.Exception.Message)"
    }
  }
  if ($processes.Count -gt 0) {
    Start-Sleep -Milliseconds 750
  }
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

  if (!(Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue)) {
    return [ordered]@{
      available = $false
      reason = 'Get-NetTCPConnection is unavailable on this Windows host.'
    }
  }

  try {
    $tcp = @(Get-NetTCPConnection -ErrorAction Stop | Where-Object {
      $ProcessIds -contains $_.OwningProcess
    })
    $udp = @()
    if (Get-Command Get-NetUDPEndpoint -ErrorAction SilentlyContinue) {
      $udp = @(Get-NetUDPEndpoint -ErrorAction Stop | Where-Object {
        $ProcessIds -contains $_.OwningProcess
      })
    }

    $states = [ordered]@{}
    foreach ($connection in $tcp) {
      $state = [string]$connection.State
      if (!$states.Contains($state)) {
        $states[$state] = 0
      }
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
      if (!$match.Success) {
        continue
      }
      $pidValue = [int]$match.Groups[1].Value
      if ($ProcessIds -notcontains $pidValue) {
        continue
      }

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
    # Historical pre-source-built Ghosium releases used the validated portable
    # profile switch and intentionally rejected direct --user-data-dir input.
    "--ghosium-portable-profile=$ProfilePath"
  }

  $arguments = @(
    $profileArgument,
    '--no-first-run',
    '--no-default-browser-check',
    $Url
  )

  Start-Process -FilePath $BrowserPath -ArgumentList $arguments -PassThru
}

function Measure-Startup {
  param(
    [string]$ProfilePath,
    [bool]$FreshProfile,
    [string]$Label
  )

  Stop-GhosiumProcesses
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

  Stop-GhosiumProcesses
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

Stop-GhosiumProcesses
if (Test-Path $ProfileRoot) {
  Remove-Item $ProfileRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $ProfileRoot | Out-Null

$startupProfile = Join-Path $ProfileRoot 'startup'
$cold = Measure-Startup -ProfilePath $startupProfile -FreshProfile $true -Label 'cold'
Stop-GhosiumProcesses
$warm = Measure-Startup -ProfilePath $startupProfile -FreshProfile $false -Label 'warm'

$oneTab = Measure-TabScenario -ProfilePath (Join-Path $ProfileRoot 'tabs-1') -TabCount 1 -MeasureOneMinuteIdle $true
$fiveTabs = Measure-TabScenario -ProfilePath (Join-Path $ProfileRoot 'tabs-5') -TabCount 5 -MeasureOneMinuteIdle $false
$tenTabs = Measure-TabScenario -ProfilePath (Join-Path $ProfileRoot 'tabs-10') -TabCount 10 -MeasureOneMinuteIdle $false

Stop-GhosiumProcesses

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
    warmStartup = 'Same isolated profile reopened after browser process cleanup. OS filesystem cache is left intact.'
    usableWindow = 'First Ghosium Browser or Ghosium Engine process exposing a non-zero MainWindowHandle.'
    tabPages = $PageUrl
    idleSeconds = $IdleSeconds
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
