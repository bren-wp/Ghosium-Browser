param(
  [Parameter(Mandatory = $false)]
  [string]$Destination = 'engine-work',

  [Parameter(Mandatory = $false)]
  [switch]$SkipHooks,

  [Parameter(Mandatory = $false)]
  [switch]$ReuseExisting
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceRevision = (Get-Content (Join-Path $repoRoot 'ENGINE_SOURCE_REVISION') -Raw).Trim()
if ($sourceRevision -notmatch '^[0-9a-f]{40}$') {
  throw 'ENGINE_SOURCE_REVISION is not a valid pinned Git commit.'
}

$fetchCommand = Get-Command fetch -ErrorAction SilentlyContinue
$gclientCommand = Get-Command gclient -ErrorAction SilentlyContinue
if (!$fetchCommand -or !$gclientCommand) {
  throw 'Chromium depot_tools must be installed and on PATH before bootstrapping the full-source checkout.'
}

if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
  $env:DEPOT_TOOLS_WIN_TOOLCHAIN = '0'

  # depot_tools git_cache.py intentionally invokes git.bat on Windows. The
  # GitHub-hosted Windows image exposes Git as git.exe but does not provide a
  # compatible git.bat command. Keep the pinned depot_tools checkout immutable
  # and provide an isolated hosted-only forwarding shim to the exact resolved
  # Git executable instead of modifying Chromium tooling.
  if ($env:GITHUB_ACTIONS -eq 'true' -and !(Get-Command git.bat -ErrorAction SilentlyContinue)) {
    $gitCommand = Get-Command git.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if (!$gitCommand -or [string]::IsNullOrWhiteSpace([string]$gitCommand.Source)) {
      throw 'GitHub-hosted Chromium bootstrap requires a resolvable git.exe before creating the depot_tools git.bat compatibility shim.'
    }

    $shimRoot = Join-Path $env:RUNNER_TEMP 'ghosium-git-shim'
    New-Item -ItemType Directory -Force -Path $shimRoot | Out-Null
    $shimPath = Join-Path $shimRoot 'git.bat'
    $shimLines = @(
      '@echo off'
      "`"$([IO.Path]::GetFullPath([string]$gitCommand.Source))`" %*"
    )
    [IO.File]::WriteAllText(
      $shimPath,
      (($shimLines -join "`r`n") + "`r`n"),
      [Text.Encoding]::ASCII
    )
    $env:PATH = "$shimRoot;$($env:PATH)"

    $resolvedShim = Get-Command git.bat -ErrorAction SilentlyContinue | Select-Object -First 1
    if (!$resolvedShim -or [IO.Path]::GetFullPath([string]$resolvedShim.Source) -ne [IO.Path]::GetFullPath($shimPath)) {
      throw 'Unable to expose the isolated hosted git.bat compatibility shim to depot_tools.'
    }
    Write-Host "GitHub-hosted depot_tools Git compatibility shim: $shimPath -> $($gitCommand.Source)"
  }
}

# The full-source workflow intentionally supplies an absolute persistent Windows
# workspace. Join-Path does not treat an absolute ChildPath as replacing its
# parent (for example, Join-Path C:\repo C:\src yields an invalid composite
# path), so absolute and relative destinations must be resolved separately.
if ([IO.Path]::IsPathFullyQualified($Destination)) {
  $destinationPath = [IO.Path]::GetFullPath($Destination)
} else {
  $destinationPath = [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Destination))
}
$src = Join-Path $destinationPath 'src'
$existingItems = @()
if (Test-Path $destinationPath) {
  $existingItems = @(Get-ChildItem $destinationPath -Force -ErrorAction SilentlyContinue)
}

$reuseCheckout = $existingItems.Count -gt 0
if ($reuseCheckout -and !$ReuseExisting) {
  throw "Destination is not empty. Pass -ReuseExisting only for a controlled Chromium builder checkout: $destinationPath"
}

if ($reuseCheckout) {
  if (!(Test-Path (Join-Path $src '.git')) -or !(Test-Path (Join-Path $destinationPath '.gclient') -PathType Leaf)) {
    throw "Existing destination is not a reusable Chromium depot_tools checkout: $destinationPath"
  }

  Write-Host "Reusing controlled Chromium checkout at $destinationPath"
  & git -C $src reset --hard HEAD
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to reset the reusable Chromium checkout.'
  }
  & git -C $src clean -ffd
  if ($LASTEXITCODE -ne 0) {
    throw 'Unable to remove untracked source files from the reusable Chromium checkout.'
  }
} else {
  New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
  Push-Location $destinationPath
  try {
    Write-Host "Fetching Chromium source for Ghosium into $destinationPath"
    & $fetchCommand.Source --nohooks --no-history chromium
    if ($LASTEXITCODE -ne 0) {
      throw "Chromium fetch failed with exit code $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }

  if (!(Test-Path (Join-Path $src '.git'))) {
    throw 'Chromium fetch did not produce the expected src Git checkout.'
  }
}

$fetchSucceeded = $false
$fetchAttempts = 3
for ($attempt = 1; $attempt -le $fetchAttempts; $attempt++) {
  & git -C $src fetch origin $sourceRevision --no-tags
  if ($LASTEXITCODE -eq 0) {
    $fetchSucceeded = $true
    break
  }

  if ($attempt -lt $fetchAttempts) {
    $retryDelaySeconds = 15 * $attempt
    Write-Warning "Pinned Chromium fetch attempt $attempt/$fetchAttempts failed; retrying the exact revision in $retryDelaySeconds seconds."
    Start-Sleep -Seconds $retryDelaySeconds
  }
}
if (!$fetchSucceeded) {
  throw "Unable to fetch pinned Chromium commit $sourceRevision after $fetchAttempts attempts"
}
& git -C $src checkout --detach $sourceRevision
if ($LASTEXITCODE -ne 0) {
  throw "Unable to detach Chromium checkout at $sourceRevision"
}
& git -C $src reset --hard $sourceRevision
if ($LASTEXITCODE -ne 0) {
  throw "Unable to reset Chromium checkout to pinned revision $sourceRevision"
}

Push-Location $destinationPath
try {
  # A persistent self-hosted checkout contains many gclient-managed Git
  # dependencies that are not cleaned by `git reset/clean` in src alone. Force
  # every dependency back to the exact DEPS state before hooks or compilation so
  # stale local edits and removed dependency trees cannot influence a later
  # verified Ghosium build.
  $syncArguments = @(
    'sync',
    '--reset',
    '--delete_unversioned_trees',
    '--force',
    '--with_branch_heads',
    '--with_tags',
    '--revision',
    "src@$sourceRevision"
  )
  if ($SkipHooks) {
    $syncArguments += '--nohooks'
  }
  & $gclientCommand.Source @syncArguments
  if ($LASTEXITCODE -ne 0) {
    throw "gclient sync failed with exit code $LASTEXITCODE"
  }

  if (!$SkipHooks) {
    & $gclientCommand.Source runhooks
    if ($LASTEXITCODE -ne 0) {
      throw "gclient runhooks failed with exit code $LASTEXITCODE"
    }
  }
} finally {
  Pop-Location
}

$actualRevision = (& git -C $src rev-parse HEAD).Trim()
if ($actualRevision -ne $sourceRevision) {
  throw "Checkout drifted from pinned revision. Expected $sourceRevision; found $actualRevision"
}

Write-Host "Pinned Chromium source ready at $src"
Write-Host "Next: $PSScriptRoot/apply-engine-branding.ps1 -SourceRoot '$src'"