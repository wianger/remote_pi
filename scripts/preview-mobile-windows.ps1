param(
    [string]$SourceApp = (Join-Path (Split-Path $PSScriptRoot -Parent) 'app'),
    [string]$BuildRoot = (Join-Path $env:LOCALAPPDATA 'RemotePiMobileBuild'),
    [string]$OutputDirectory = (Join-Path $env:USERPROFILE 'Downloads\RemotePi-UI-Preview'),
    [string]$ProxyUrl = $env:HTTPS_PROXY
)
$ErrorActionPreference = 'Stop'
$flutterRoot = 'C:\Scoop\apps\flutter\current'
$flutter = Join-Path $flutterRoot 'bin\flutter.bat'
if (-not (Test-Path -LiteralPath $flutter)) { throw 'Install Flutter with Scoop first.' }
$source = (Resolve-Path -LiteralPath $SourceApp).ProviderPath
$buildApp = Join-Path $BuildRoot 'app'
if ([IO.Path]::GetFullPath($source).TrimEnd('\') -eq [IO.Path]::GetFullPath($buildApp).TrimEnd('\')) {
    throw 'Source and build snapshot must be different directories.'
}
New-Item -ItemType Directory -Path $buildApp -Force | Out-Null
& robocopy $source $buildApp /E /XD .dart_tool build .gradle /XF local.properties key.properties /NFL /NDL /NJH /NJS /NP
if ($LASTEXITCODE -ge 8) { throw 'Source snapshot copy failed.' }

$fontDirectory = Join-Path $OutputDirectory 'fonts'
New-Item -ItemType Directory -Path $fontDirectory -Force | Out-Null
$inter = Join-Path $fontDirectory 'Inter-Bold.ttf'
# Exact Inter asset used by the locked google_fonts package. Verify the hash
# before loading it into the offline test renderer.
$fontHash = 'b7e339223d56e8c4210c86f1ba87b3d43d6c47e03956ea56f0a7a938ae61b2a3'
if (-not (Test-Path -LiteralPath $inter)) {
    $curlArguments = @('-fLsS', '--connect-timeout', '10', '--max-time', '45')
    if ($ProxyUrl) { $curlArguments += @('--proxy', $ProxyUrl) }
    $curlArguments += @("https://fonts.gstatic.com/s/a/$fontHash.ttf", '-o', $inter)
    & curl.exe @curlArguments
    if ($LASTEXITCODE -ne 0) { throw 'Preview font download failed.' }
}
if ((Get-FileHash -LiteralPath $inter -Algorithm SHA256).Hash -ne $fontHash) {
    throw 'Preview font checksum mismatch.'
}
$savedEnvironment = @{}
foreach ($name in @('REMOTE_PI_PREVIEW_DIR', 'REMOTE_PI_FONT_DIR', 'REMOTE_PI_INTER_FONT')) {
    $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
try {
    $env:REMOTE_PI_PREVIEW_DIR = [IO.Path]::GetFullPath($OutputDirectory)
    $env:REMOTE_PI_FONT_DIR = Join-Path $flutterRoot 'bin\cache\artifacts\material_fonts'
    $env:REMOTE_PI_INTER_FONT = [IO.Path]::GetFullPath($inter)
    Push-Location $buildApp
    try {
        & $flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }
        & $flutter test --no-pub --timeout 60s test/ui/workspaces/ui_preview_gallery_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'UI preview rendering failed.' }
    } finally { Pop-Location }
    Write-Output "Preview images: $OutputDirectory"
} finally {
    foreach ($name in $savedEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process')
    }
}
