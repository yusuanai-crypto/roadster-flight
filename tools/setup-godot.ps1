[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$version = '4.7.2'
$release = "$version-stable"
$baseUrl = "https://github.com/godotengine/godot-builds/releases/download/$release"
$downloadDir = Join-Path $projectRoot '.tools/downloads'
$engineDir = Join-Path $projectRoot ".tools/godot/$version"
$templateDir = Join-Path $engineDir 'templates'
New-Item -ItemType Directory -Force -Path $downloadDir, $engineDir, $templateDir | Out-Null

$editorName = "Godot_v${release}_win64.exe.zip"
$editorZip = Join-Path $downloadDir $editorName
$editorSha256 = '731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953'
if (-not (Test-Path -LiteralPath $editorZip)) {
    Invoke-WebRequest -Uri "$baseUrl/$editorName" -OutFile $editorZip
}
if ((Get-FileHash -LiteralPath $editorZip -Algorithm SHA256).Hash.ToLowerInvariant() -ne $editorSha256) {
    throw 'Editor ZIP SHA256 differs from the official GitHub release asset digest.'
}
Expand-Archive -LiteralPath $editorZip -DestinationPath $engineDir -Force

# Export templates are a 1.28 GB ZIP. Fetch only the directory and one Windows entry.
# Refuse HTTP 200 BEFORE reading its body, so a server cannot silently download it all.
$templateUrl = "$baseUrl/Godot_v${release}_export_templates.tpz"
$templateArchiveSize = [long]1281349702
$client = [System.Net.Http.HttpClient]::new()
$client.Timeout = [TimeSpan]::FromMinutes(10)
function Save-Range([long]$start, [long]$end, [string]$destination) {
    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $templateUrl)
    $request.Headers.Range = [System.Net.Http.Headers.RangeHeaderValue]::new($start, $end)
    $response = $null
    try {
        $response = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        $range = $response.Content.Headers.ContentRange
        if ([int]$response.StatusCode -ne 206 -or $null -eq $range -or
            $range.From -ne $start -or $range.To -ne $end -or $range.Length -ne $templateArchiveSize) {
            throw 'Server did not honor the exact HTTP Range; stopped without reading the body.'
        }
        $stream = [System.IO.File]::Create($destination)
        try { $null = $response.Content.CopyToAsync($stream).GetAwaiter().GetResult() }
        finally { $stream.Dispose() }
        if ((Get-Item -LiteralPath $destination).Length -ne $end - $start + 1) { throw 'Truncated range download.' }
    }
    finally {
        if ($null -ne $response) { $response.Dispose() }
        $request.Dispose()
    }
}

$tailFile = Join-Path $downloadDir 'templates-tail.bin'
Save-Range ($templateArchiveSize - 131072) ($templateArchiveSize - 1) $tailFile
$tail = [System.IO.File]::ReadAllBytes($tailFile)
$entries = @{}
for ($index = 0; $index -lt $tail.Length - 46; $index++) {
    if ([BitConverter]::ToUInt32($tail, $index) -ne 0x02014b50) { continue }
    $nameLength = [BitConverter]::ToUInt16($tail, $index + 28)
    $extraLength = [BitConverter]::ToUInt16($tail, $index + 30)
    $commentLength = [BitConverter]::ToUInt16($tail, $index + 32)
    $name = [System.Text.Encoding]::UTF8.GetString($tail, $index + 46, $nameLength)
    if ($name -in @('templates/windows_release_x86_64.exe', 'templates/icudt_godot.dat')) {
        $entries[$name] = [ordered]@{
            name = $name
            method = [BitConverter]::ToUInt16($tail, $index + 10)
            crc32 = [BitConverter]::ToUInt32($tail, $index + 16)
            compressed = [BitConverter]::ToUInt32($tail, $index + 20)
            uncompressed = [BitConverter]::ToUInt32($tail, $index + 24)
            offset = [BitConverter]::ToUInt32($tail, $index + 42)
        }
    }
    $index += 45 + $nameLength + $extraLength + $commentLength
}
if (-not ('RoadsterTooling.Crc32' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
namespace RoadsterTooling {
    public static class Crc32 {
        public static uint FileChecksum(string path) {
            uint[] table = new uint[256];
            for (uint i = 0; i < 256; ++i) {
                uint value = i;
                for (int j = 0; j < 8; ++j) value = (value & 1) == 1 ? 0xedb88320U ^ (value >> 1) : value >> 1;
                table[i] = value;
            }
            uint crc = 0xffffffffU;
            byte[] buffer = new byte[1024 * 1024];
            using (FileStream stream = File.OpenRead(path)) {
                int count;
                while ((count = stream.Read(buffer, 0, buffer.Length)) > 0)
                    for (int i = 0; i < count; ++i) crc = table[(crc ^ buffer[i]) & 255] ^ (crc >> 8);
            }
            return crc ^ 0xffffffffU;
        }
    }
}
'@
}
foreach ($entryName in @('templates/windows_release_x86_64.exe', 'templates/icudt_godot.dat')) {
    $entry = $entries[$entryName]
    if ($null -eq $entry -or $entry.method -ne 8) { throw "Missing or unsupported ZIP entry: $entryName" }
    $leafName = Split-Path -Leaf $entryName
    $destinationPath = Join-Path $templateDir $leafName
    if ((Test-Path -LiteralPath $destinationPath) -and
        (Get-Item -LiteralPath $destinationPath).Length -eq $entry.uncompressed -and
        [RoadsterTooling.Crc32]::FileChecksum($destinationPath) -eq $entry.crc32) { continue }
    $headerFile = Join-Path $downloadDir "$leafName.local-header.bin"
    Save-Range $entry.offset ($entry.offset + 29) $headerFile
    $header = [System.IO.File]::ReadAllBytes($headerFile)
    if ([BitConverter]::ToUInt32($header, 0) -ne 0x04034b50) { throw 'Bad ZIP local header.' }
    $dataOffset = $entry.offset + 30 + [BitConverter]::ToUInt16($header, 26) + [BitConverter]::ToUInt16($header, 28)
    $compressedFile = Join-Path $downloadDir "$leafName.deflate"
    Save-Range $dataOffset ($dataOffset + $entry.compressed - 1) $compressedFile
    $compressedStream = [System.IO.File]::OpenRead($compressedFile)
    $deflate = [System.IO.Compression.DeflateStream]::new($compressedStream, [System.IO.Compression.CompressionMode]::Decompress)
    $destination = [System.IO.File]::Create($destinationPath)
    try { $deflate.CopyTo($destination) }
    finally { $destination.Dispose(); $deflate.Dispose(); $compressedStream.Dispose() }
    if ((Get-Item -LiteralPath $destinationPath).Length -ne $entry.uncompressed -or
        [RoadsterTooling.Crc32]::FileChecksum($destinationPath) -ne $entry.crc32) {
        throw "ZIP length/CRC32 validation failed: $leafName"
    }
}
$client.Dispose()
$templatePath = Join-Path $templateDir 'windows_release_x86_64.exe'
Invoke-WebRequest -Uri "$baseUrl/SHA512-SUMS.txt" -OutFile (Join-Path $downloadDir 'SHA512-SUMS.txt')
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/godotengine/godot/$release/LICENSE.txt" -OutFile (Join-Path $engineDir 'LICENSE-Godot.txt')
$console = Join-Path $engineDir "Godot_v${release}_win64_console.exe"
$actualVersion = (& $console --version | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or -not $actualVersion.StartsWith('4.7.2.stable.official.')) { throw "Unexpected Godot version: $actualVersion" }
$record = [ordered]@{
    version = $actualVersion
    release = "https://github.com/godotengine/godot-builds/releases/tag/$release"
    editor_url = "$baseUrl/$editorName"
    editor_zip_sha256 = $editorSha256
    editor_integrity = 'Verified against official GitHub release asset SHA256 digest.'
    template_archive_url = $templateUrl
    template_archive_size = $templateArchiveSize
    template_archive_official_sha256 = 'f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011'
    template_extraction = 'HTTP 206 ranges: ZIP central directory, local header, compressed Windows release entry only.'
    template_entries = $entries
    template_sha256 = (Get-FileHash -LiteralPath $templatePath -Algorithm SHA256).Hash.ToLowerInvariant()
    template_integrity = 'ZIP directory CRC32 and decompressed size verified. Full archive SHA256 cannot be checked with a partial download.'
    icu_data_sha256 = (Get-FileHash -LiteralPath (Join-Path $templateDir 'icudt_godot.dat') -Algorithm SHA256).Hash.ToLowerInvariant()
    license_url = "https://raw.githubusercontent.com/godotengine/godot/$release/LICENSE.txt"
}
$record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $engineDir 'source-record.json') -Encoding utf8
Write-Output "Godot ready: $actualVersion"
Write-Output "Editor: $console"
Write-Output "Template: $templatePath"
