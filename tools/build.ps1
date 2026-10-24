[CmdletBinding()]
param(
    [string]$GodotPath = '',
    [string]$OutputDirectory = 'builds/windows-v0.5',
    [switch]$SkipImport
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($GodotPath)) {
    $GodotPath = Join-Path $projectRoot '.tools/godot/4.7.2/Godot_v4.7.2-stable_win64_console.exe'
}
if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Godot is missing. First run: powershell -ExecutionPolicy Bypass -File tools/setup-godot.ps1'
}
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'project.godot'))) { throw 'project.godot is missing.' }
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot '.tools/godot/4.7.2/templates/windows_release_x86_64.exe'))) {
    throw 'The Windows release template is missing. Run tools/setup-godot.ps1.'
}
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { throw 'OutputDirectory must not be empty.' }
$outputDir = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $projectRoot $OutputDirectory))
}
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
$profileDir = Join-Path $projectRoot '.tools/godot-profile'
$appData = Join-Path $profileDir 'appdata'
$localAppData = Join-Path $profileDir 'localappdata'
$tempDir = Join-Path $profileDir 'temp'
$installedTemplates = Join-Path $appData 'Godot/export_templates/4.7.2.stable'
New-Item -ItemType Directory -Force -Path $appData, $localAppData, $tempDir, $installedTemplates | Out-Null
$icuData = Join-Path $projectRoot '.tools/godot/4.7.2/templates/icudt_godot.dat'
if (-not (Test-Path -LiteralPath $icuData)) { throw 'ICU data is missing. Run tools/setup-godot.ps1.' }
Copy-Item -LiteralPath $icuData -Destination (Join-Path $installedTemplates 'icudt_godot.dat') -Force

function Invoke-Godot([string[]]$Arguments, [string]$LogName) {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $GodotPath
    $startInfo.WorkingDirectory = $projectRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    # This environment belongs only to this child; no user or system variables change.
    $startInfo.EnvironmentVariables['APPDATA'] = $appData
    $startInfo.EnvironmentVariables['LOCALAPPDATA'] = $localAppData
    $startInfo.EnvironmentVariables['TMP'] = $tempDir
    $startInfo.EnvironmentVariables['TEMP'] = $tempDir
    $logPath = Join-Path $outputDir $LogName
    $allArguments = @('--headless', '--path', $projectRoot, '--log-file', $logPath) + $Arguments
    $startInfo.Arguments = ($allArguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' '
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $process.WaitForExit()
    $exitCode = $process.ExitCode
    $process.Dispose()
    if ($exitCode -ne 0) { throw "Godot failed ($exitCode); see $logPath." }
    if (-not (Test-Path -LiteralPath $logPath)) { throw "Godot did not produce its expected log: $logPath" }
    $engineErrors = @(Select-String -LiteralPath $logPath -Pattern '(?i)\b(?:ERROR|Parse Error|Script Error)\b')
    if ($engineErrors.Count -gt 0) {
        $details = ($engineErrors | Select-Object -First 8 | ForEach-Object { $_.Line.Trim() }) -join [Environment]::NewLine
        throw "Godot reported errors despite exit code 0; see $logPath.$([Environment]::NewLine)$details"
    }
}
if (-not $SkipImport) {
    Invoke-Godot @('--editor', '--import') 'import.log'
}
$output = Join-Path $outputDir 'RoadsterFlight.exe'
Invoke-Godot @('--export-release', 'Windows Desktop', $output) 'export.log'
if (-not (Test-Path -LiteralPath $output) -or (Get-Item -LiteralPath $output).Length -lt 1MB) { throw 'Windows executable was not produced.' }
$license = Join-Path $projectRoot '.tools/godot/4.7.2/LICENSE-Godot.txt'
if (-not (Test-Path -LiteralPath $license)) { throw 'The Godot MIT license is missing. Run tools/setup-godot.ps1.' }
Copy-Item -LiteralPath $license -Destination (Join-Path $outputDir 'LICENSE-Godot.txt') -Force
Copy-Item -LiteralPath $icuData -Destination (Join-Path $outputDir 'icudt_godot.dat') -Force
$sourceRecord = Join-Path $projectRoot '.tools/godot/4.7.2/source-record.json'
Copy-Item -LiteralPath $sourceRecord -Destination (Join-Path $outputDir 'engine-source-record.json') -Force
Write-Output "Windows build ready: $output"
Get-FileHash -LiteralPath $output -Algorithm SHA256 | Format-List
