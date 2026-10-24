[CmdletBinding()]
param(
    [string]$BuildDirectory = 'builds/windows-v0.5',
    [string]$Version = '0.5',
    [string]$QaDirectory = 'builds/qa/v5'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $BuildDirectory))
$qaRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $QaDirectory))
$zipPath = Join-Path $projectRoot ('builds/RoadsterFlight-v' + $Version + '-Windows.zip')
$instructions = Join-Path $projectRoot ('docs/试玩说明-v' + $Version + '.txt')
Copy-Item -LiteralPath $instructions -Destination (Join-Path $buildRoot '试玩说明.txt') -Force
New-Item -ItemType Directory -Force -Path $qaRoot | Out-Null
$names = @('RoadsterFlight.exe', 'icudt_godot.dat', 'LICENSE-Godot.txt', 'engine-source-record.json', '试玩说明.txt')
foreach ($name in $names) {
    if (-not (Test-Path -LiteralPath (Join-Path $buildRoot $name))) { throw "Missing release file: $name" }
}
Add-Type -AssemblyName System.IO.Compression
$file = [IO.File]::Open($zipPath, [IO.FileMode]::Create)
try {
    $archive = [IO.Compression.ZipArchive]::new($file, [IO.Compression.ZipArchiveMode]::Create, $true)
    try {
        foreach ($name in $names) {
            $entry = $archive.CreateEntry($name, [IO.Compression.CompressionLevel]::Optimal)
            $source = [IO.File]::OpenRead((Join-Path $buildRoot $name))
            $destination = $entry.Open()
            try { $source.CopyTo($destination) } finally { $destination.Dispose(); $source.Dispose() }
        }
    } finally { $archive.Dispose() }
} finally { $file.Dispose() }
$checks = @()
$file = [IO.File]::OpenRead($zipPath)
try {
    $archive = [IO.Compression.ZipArchive]::new($file, [IO.Compression.ZipArchiveMode]::Read, $true)
    try {
        if ($archive.Entries.Count -ne $names.Count) { throw 'Unexpected ZIP entry count.' }
        foreach ($name in $names) {
            $entry = $archive.GetEntry($name)
            if ($null -eq $entry) { throw "ZIP is missing $name" }
            $expected = (Get-FileHash -LiteralPath (Join-Path $buildRoot $name) -Algorithm SHA256).Hash.ToLowerInvariant()
            $stream = $entry.Open()
            $sha = [Security.Cryptography.SHA256]::Create()
            try { $actual = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
            finally { $sha.Dispose(); $stream.Dispose() }
            $length = (Get-Item -LiteralPath (Join-Path $buildRoot $name)).Length
            if ($actual -ne $expected -or $entry.Length -ne $length) { throw "ZIP verification failed: $name" }
            $checks += [ordered]@{ name = $name; bytes = $length; sha256 = $actual; verified = $true }
        }
    } finally { $archive.Dispose() }
} finally { $file.Dispose() }
$result = [ordered]@{
    package = $zipPath
    bytes = (Get-Item -LiteralPath $zipPath).Length
    sha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    entries = $checks
    verified = $true
}
$result | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $qaRoot 'package-check.json') -Encoding utf8
$result | ConvertTo-Json -Depth 5
