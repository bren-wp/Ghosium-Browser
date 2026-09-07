param(
  [Parameter(Mandatory = $true)]
  [string]$BrowserPath,

  [Parameter(Mandatory = $true)]
  [string]$OutputPath,

  [int]$IdleSeconds = 60,
  [int]$StartupTimeoutSeconds = 30,
  [string]$ProfileRoot = "$env:RUNNER_TEMP\ghosium-performance-profile",
  [string]$PageUrl = 'https://example.com/'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-GhosiumProcesses {
  @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessName -in @('Ghosium-Browser', 'Ghosium-Engine')
  })
}

function Stop-GhosiumProcesses {
  $processes = Get-GhosiumProcesses
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

function Get-NetworkConnectionCount {
  param([int[]]$ProcessIds)

  if (!(Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue)) {
    return $null
  }

  try {
    $connections = @(Get-NetTCPConnection -ErrorAction Stop | Where-Object {
      $ProcessIds -contains $_.OwningProcess -and $_.State -notin @('Listen', 'Closed')
    })
    return $connections.Count
  } catch {
    return $null
  }
}

function Get-BrowserSample {
  $processes = Get-GhosiumProcesses
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
    activeTcpConnections = Get-NetworkConnectionCount -ProcessIds $ids
  }
}

function Measure-IdleCpu {
  param([int]$Seconds = 5)

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

  # The Ghosium launcher deliberately rejects direct --user-data-dir overrides
  # to protect the profile boundary. The benchmark therefore uses the launcher's
  # validated portable-profile control so every sample really is isolated.
  $arguments = @(
    "--ghosium-portable-profile=$ProfilePath",
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
  $launcher = Start-Ghosium -ProfilePath $ProfilePath -Url "$PageUrl?ghosium-startup=$Label"
  $window = Wait-ForUsableWindow -Stopwatch $stopwatch
  $stopwatch.Stop()

  Start-Sleep -Seconds 2
  $sample = Get-BrowserSample

  [ordered]@{
    label = $Label
    launcherProcessId = $launcher.Id
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
  Start-Ghosium -ProfilePath $ProfilePath -Url "$PageUrl?ghosium-tab=1" | Out-Null
  $window = Wait-ForUsableWindow -Stopwatch $stopwatch
  $stopwatch.Stop()

  for ($index = 2; $index -le $TabCount; $index++) {
    Start-Ghosium -ProfilePath $ProfilePath -Url "$PageUrl?ghosium-tab=$index" | Out-Null
    Start-Sleep -Milliseconds 250
  }

  Start-Sleep -Seconds 3
  $settled = Get-BrowserSample
  $idleCpu = Measure-IdleCpu -Seconds 5
  $afterIdle = $null

  if ($MeasureOneMinuteIdle) {
    Start-Sleep -Seconds $IdleSeconds
    $afterIdle = Get-BrowserSample
  }

  [ordered]@{
    tabCount = $TabCount
    launchToUsableWindowMs = $window.firstUsableWindowMs
    settledSample = $settled
    idleCpu = $idleCpu
    afterIdleSample = $afterIdle
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
  schemaVersion = 1
  capturedAtUtc = [DateTime]::UtcNow.ToString('o')
  browserPath = $BrowserPath
  host = [ordered]@{
    machineName = $env:COMPUTERNAME
    os = [Environment]::OSVersion.VersionString
    logicalProcessors = [Environment]::ProcessorCount
    totalPhysicalMemoryBytes = [uint64](Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
  }
  methodology = [ordered]@{
    coldStartup = 'Fresh isolated Ghosium profile selected through --ghosium-portable-profile and no running Ghosium processes. OS filesystem cache is not forcibly flushed.'
    warmStartup = 'Same isolated Ghosium profile reopened after a clean browser shutdown. OS filesystem cache is left intact.'
    usableWindow = 'First Ghosium Browser or Ghosium Engine process exposing a non-zero MainWindowHandle.'
    tabPages = $PageUrl
    idleSeconds = $IdleSeconds
    gpuMemory = 'Not reported by this harness until a reliable per-process Windows GPU counter mapping is added.'
    network = 'Reports active TCP connection count for Ghosium-owned process IDs; byte-level network attribution is not yet reported.'
  }
  startup = [ordered]@{
    cold = $cold
    warm = $warm
  }
  tabs = @($oneTab, $fiveTabs, $tenTabs)
}

$result | ConvertTo-Json -Depth 12 | Set-Content $OutputPath -Encoding utf8
Write-Host "Ghosium benchmark written to $OutputPath"
