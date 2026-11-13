[CmdletBinding()]
param(
    [ValidateSet('latest', 'android11')]
    [string] $Device = 'latest',
    [switch] $RunApp,
    [switch] $List,
    [switch] $Stop
)

$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
$workspaceRoot = Split-Path -Parent (Split-Path -Parent $projectRoot)
$toolsRoot = Join-Path $workspaceRoot '.devtools'
$sdkRoot = Join-Path $toolsRoot 'android-sdk'
$flutterRoot = Join-Path $toolsRoot 'flutter'
$javaRoot = Join-Path $toolsRoot 'jdk-stage\jdk-17.0.20.1+1'
$userHome = Join-Path $toolsRoot 'android-user-home'
$avdHome = Join-Path $userHome 'avd'

$env:ANDROID_HOME = $sdkRoot
$env:ANDROID_SDK_ROOT = $sdkRoot
$env:ANDROID_USER_HOME = $userHome
$env:ANDROID_AVD_HOME = $avdHome
$env:JAVA_HOME = $javaRoot
$env:PUB_CACHE = Join-Path $toolsRoot 'pub-cache'
$env:GRADLE_USER_HOME = Join-Path $toolsRoot 'gradle-user-home'
$env:LOCALAPPDATA = Join-Path $toolsRoot 'local-appdata'
$env:APPDATA = Join-Path $toolsRoot 'roaming-appdata'
Remove-Item Env:ANDROID_SDK_HOME -ErrorAction SilentlyContinue

$env:GIT_CONFIG_COUNT = '1'
$env:GIT_CONFIG_KEY_0 = 'safe.directory'
$env:GIT_CONFIG_VALUE_0 = Join-Path $toolsRoot 'flutter'
$env:PATH = "$flutterRoot\bin;$sdkRoot\platform-tools;$sdkRoot\emulator;$sdkRoot\cmdline-tools\latest\bin;$javaRoot\bin;$env:PATH"

$adb = Join-Path $sdkRoot 'platform-tools\adb.exe'
$emulator = Join-Path $sdkRoot 'emulator\emulator.exe'
$avdManager = Join-Path $sdkRoot 'cmdline-tools\latest\bin\avdmanager.bat'

if ($List) {
    & $avdManager list avd
    exit 0
}

if ($Stop) {
    & $adb start-server | Out-Null
    $runningSerials = @(
        & $adb devices | Where-Object { $_ -match '^emulator-\d+\s+device$' } |
            ForEach-Object { ($_ -split '\s+')[0] }
    )
    foreach ($serial in $runningSerials) {
        & $adb -s $serial emu kill | Out-Null
    }
    if ($runningSerials.Count -eq 0) {
        Write-Host 'No Android emulator is running.'
    }
    exit 0
}

$avdName = if ($Device -eq 'latest') {
    'FixEase_Pixel6_API37'
}
else {
    'FixEase_Pixel6_API30'
}

if (-not (Test-Path -LiteralPath (Join-Path $avdHome "$avdName.ini"))) {
    throw "AVD '$avdName' is not installed. Run this script with -List to inspect the available devices."
}

$accelerationOutput = @(& $emulator -accel-check 2>&1)
$accelerationText = $accelerationOutput -join ' '
if ($accelerationText -notmatch '(?i)(WHPX|AEHD|GVM|KVM).*(installed and usable|is usable)') {
    Write-Host $accelerationText
    throw 'No usable hardware hypervisor was detected, so the emulator was not started. Enable Windows Hypervisor Platform (WHPX), then restart Windows before launching this AVD.'
}

& $adb start-server | Out-Null
$runningSerials = @(
    & $adb devices | Where-Object { $_ -match '^emulator-\d+\s+device$' } |
        ForEach-Object { ($_ -split '\s+')[0] }
)
if ($runningSerials.Count -gt 0) {
    throw "An emulator is already running ($($runningSerials -join ', ')). Run this script with -Stop before starting another to keep computer load low."
}

Start-Process -FilePath $emulator `
    -ArgumentList @('-avd', $avdName, '-gpu', 'auto', '-cores', '2', '-memory', '2048') `
    -WorkingDirectory (Join-Path $sdkRoot 'emulator') | Out-Null

$serial = 'emulator-5554'
$bootDeadline = (Get-Date).AddMinutes(5)
$booted = $false
while ((Get-Date) -lt $bootDeadline) {
    $bootState = & $adb -s $serial shell getprop sys.boot_completed 2>$null
    if (($bootState | Select-Object -Last 1).ToString().Trim() -eq '1') {
        $booted = $true
        break
    }
    Start-Sleep -Seconds 3
}

if (-not $booted) {
    throw "'$avdName' did not finish booting within five minutes. Check Windows virtualization with '$sdkRoot\emulator\emulator.exe -accel-check'."
}

Write-Host "Ready: $avdName ($serial). Only one emulator is started at a time; it is configured for 2 CPU cores and 2 GB RAM."

if ($RunApp) {
    Push-Location $projectRoot
    try {
        & (Join-Path $flutterRoot 'bin\flutter.bat') run -d $serial
        $flutterExitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
    exit $flutterExitCode
}
