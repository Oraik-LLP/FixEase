param(
    [string]$SigningCredentialsFile,
    [int]$BuildNumber = 17,
    [string]$BuildName = '1.1.0',
    [ValidateSet('beta', 'production')][string]$Channel = 'production',
    [string]$DartDefineFile = (Join-Path $PSScriptRoot '.local\play-defines.json')
)

$ErrorActionPreference = 'Stop'

if ($SigningCredentialsFile) {
    $credentialNames = @{
        Alias = 'FIXEASE_UPLOAD_KEY_ALIAS'
        Keystore = 'FIXEASE_UPLOAD_STORE_FILE'
        StorePassword = 'FIXEASE_UPLOAD_STORE_PASSWORD'
        KeyPassword = 'FIXEASE_UPLOAD_KEY_PASSWORD'
    }
    foreach ($line in Get-Content -LiteralPath $SigningCredentialsFile) {
        if ($line -match '^\s*(Alias|Keystore|StorePassword|KeyPassword)\s*[:=]\s*(.+?)\s*$') {
            [Environment]::SetEnvironmentVariable($credentialNames[$matches[1]], $matches[2], 'Process')
        }
    }
}
if (Test-Path -LiteralPath $DartDefineFile) {
    $defines = Get-Content -LiteralPath $DartDefineFile -Raw | ConvertFrom-Json
    if (-not $env:REVENUECAT_ANDROID_API_KEY) {
        $env:REVENUECAT_ANDROID_API_KEY = $defines.REVENUECAT_ANDROID_API_KEY
    }
}

$requiredVariables = @(
    'FIXEASE_UPLOAD_STORE_FILE',
    'FIXEASE_UPLOAD_STORE_PASSWORD',
    'FIXEASE_UPLOAD_KEY_ALIAS',
    'FIXEASE_UPLOAD_KEY_PASSWORD',
    'REVENUECAT_ANDROID_API_KEY'
)
$missingVariables = @(
    $requiredVariables | Where-Object {
        [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($_))
    }
)
if ($missingVariables.Count -gt 0) {
    throw "Set the existing Play upload-key variables and REVENUECAT_ANDROID_API_KEY before building. Missing: $($missingVariables -join ', ')."
}

if (-not (Test-Path -LiteralPath $env:FIXEASE_UPLOAD_STORE_FILE -PathType Leaf)) {
    throw 'FIXEASE_UPLOAD_STORE_FILE must point to the existing upload keystore for the published app.'
}

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$flutter = Join-Path $workspaceRoot '.devtools\flutter\bin\flutter.bat'
if (-not (Test-Path -LiteralPath $flutter -PathType Leaf)) {
    throw "Workspace Flutter SDK was not found. See FixEase\DEV_SETUP.md."
}

$env:ANDROID_HOME = Join-Path $workspaceRoot '.devtools\android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:ANDROID_USER_HOME = Join-Path $workspaceRoot '.devtools\android-user-home'
New-Item -ItemType Directory -Force -Path $env:ANDROID_USER_HOME | Out-Null
Remove-Item Env:ANDROID_SDK_HOME -ErrorAction SilentlyContinue
$env:JAVA_HOME = Join-Path $workspaceRoot '.devtools\jdk-stage\jdk-17.0.20.1+1'
$env:PUB_CACHE = Join-Path $workspaceRoot '.devtools\pub-cache'
$env:GRADLE_USER_HOME = Join-Path $workspaceRoot '.devtools\gradle-user-home'
$env:LOCALAPPDATA = Join-Path $workspaceRoot '.devtools\local-appdata'
$env:APPDATA = Join-Path $workspaceRoot '.devtools\roaming-appdata'
$env:GIT_CONFIG_COUNT = '1'
$env:GIT_CONFIG_KEY_0 = 'safe.directory'
$env:GIT_CONFIG_VALUE_0 = Join-Path $workspaceRoot '.devtools\flutter'
$env:PATH = "$((Split-Path -Parent $flutter));$env:ANDROID_HOME\platform-tools;$env:JAVA_HOME\bin;$env:PATH"

$releaseDefines = @(
    "--build-number=$BuildNumber",
    "--build-name=$BuildName",
    "--dart-define=FIXEASE_BUILD_NAME=$BuildName",
    "--dart-define=FIXEASE_BUILD_NUMBER=$BuildNumber",
    "--dart-define=FIXEASE_RELEASE_CHANNEL=$Channel",
    '--dart-define=FIXEASE_DEMO_MODE=false',
    '--dart-define=AI_BACKEND_URL=https://api.fixease.oraik.co',
    "--dart-define=REVENUECAT_ANDROID_API_KEY=$env:REVENUECAT_ANDROID_API_KEY"
)

Push-Location $PSScriptRoot
try {
    & $flutter build appbundle --release --no-pub @releaseDefines
    if ($LASTEXITCODE -ne 0) {
        throw "Play Store App Bundle build failed with exit code $LASTEXITCODE."
    }

    & $flutter build apk --release --no-pub @releaseDefines
    if ($LASTEXITCODE -ne 0) {
        throw "Signed release APK build failed with exit code $LASTEXITCODE."
    }
    $outputDirectory = Join-Path $PSScriptRoot "finrel\v$BuildNumber"
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'build\app\outputs\bundle\release\app-release.aab') -Destination (Join-Path $outputDirectory "FixEase-$BuildName-v$BuildNumber.aab")
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk') -Destination (Join-Path $outputDirectory "FixEase-$BuildName-v$BuildNumber.apk")
} finally {
    Pop-Location
}
