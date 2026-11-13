[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]] $AndroidCliArgs = @()
)

$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$toolsRoot = Join-Path $workspaceRoot '.devtools'
$sdkRoot = Join-Path $toolsRoot 'android-sdk'
$profileRoot = Join-Path $toolsRoot 'android-cli\profile'
$androidCli = Join-Path $toolsRoot 'android-cli\android.exe'

if (-not (Test-Path -LiteralPath $androidCli)) {
    throw "Android CLI is missing: $androidCli"
}

New-Item -ItemType Directory -Force -Path $profileRoot | Out-Null
if (-not $AndroidCliArgs -or $AndroidCliArgs.Count -eq 0) {
    $AndroidCliArgs = @('info')
}

# Keep Android CLI state inside this workspace rather than the Windows profile.
$previousUserProfile = $env:USERPROFILE
try {
    $env:USERPROFILE = $profileRoot
    & $androidCli '--no-metrics' "--sdk=$sdkRoot" @AndroidCliArgs
    $androidCliExitCode = $LASTEXITCODE
}
finally {
    $env:USERPROFILE = $previousUserProfile
}

exit $androidCliExitCode
