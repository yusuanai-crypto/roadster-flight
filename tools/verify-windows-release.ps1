[CmdletBinding()]
param(
    [string]$BuildDirectory = 'builds/windows-v0.5',
    [string]$QaDirectory = 'builds/qa/v5'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $BuildDirectory))
$qaRoot = [IO.Path]::GetFullPath((Join-Path $projectRoot $QaDirectory))
New-Item -ItemType Directory -Force -Path $qaRoot | Out-Null
$start = [Diagnostics.ProcessStartInfo]::new()
$start.FileName = Join-Path $buildRoot 'RoadsterFlight.exe'
$start.WorkingDirectory = $buildRoot
$start.Arguments = '--log-file "' + (Join-Path $qaRoot 'release.log') + '"'
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
# Keep the normal player's record and shader cache untouched.
foreach ($entry in @{ APPDATA = 'appdata'; LOCALAPPDATA = 'localappdata'; TEMP = 'temp'; TMP = 'temp' }.GetEnumerator()) {
    $profilePath = Join-Path $projectRoot ('.tools/qa-release/' + $entry.Value)
    New-Item -ItemType Directory -Force -Path $profilePath | Out-Null
    $start.EnvironmentVariables[$entry.Key] = $profilePath
}
$process = [Diagnostics.Process]::Start($start)
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
$windowFound = $false
$deadline = [DateTime]::UtcNow.AddSeconds(15)
while (-not $process.HasExited -and [DateTime]::UtcNow -lt $deadline) {
    $process.Refresh()
    if ($process.MainWindowHandle -ne [IntPtr]::Zero) {
        $windowFound = $true
        break
    }
    Start-Sleep -Milliseconds 100
}
if (-not $windowFound) {
    if (-not $process.HasExited) { $process.Kill() }
    throw 'Standalone EXE did not create a real window.'
}
Start-Sleep -Milliseconds 1200
if (-not ('RoadsterReleaseWindow' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class RoadsterReleaseWindow {
    [StructLayout(LayoutKind.Sequential)]
    public struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)]
    public struct MonitorInfo { public int Size; public Rect Monitor, Work; public uint Flags; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out Rect rect);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out Rect rect);
    [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr h, uint flags);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool GetMonitorInfo(IntPtr h, ref MonitorInfo info);
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int index);
    [DllImport("user32.dll")] public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
}
'@
}
$previousDpi = [RoadsterReleaseWindow]::SetThreadDpiAwarenessContext([IntPtr]::new(-4))
try {
    $windowRect = [RoadsterReleaseWindow+Rect]::new()
    $clientRect = [RoadsterReleaseWindow+Rect]::new()
    $monitor = [RoadsterReleaseWindow+MonitorInfo]::new()
    $monitor.Size = [Runtime.InteropServices.Marshal]::SizeOf($monitor)
    $monitorHandle = [RoadsterReleaseWindow]::MonitorFromWindow($process.MainWindowHandle, 2)
    if (-not [RoadsterReleaseWindow]::GetWindowRect($process.MainWindowHandle, [ref]$windowRect) -or
        -not [RoadsterReleaseWindow]::GetClientRect($process.MainWindowHandle, [ref]$clientRect) -or
        -not [RoadsterReleaseWindow]::GetMonitorInfo($monitorHandle, [ref]$monitor)) {
        throw 'Could not inspect standalone window and monitor bounds.'
    }
    $style = [RoadsterReleaseWindow]::GetWindowLong($process.MainWindowHandle, -16)
    $fillsMonitor = $windowRect.Left -eq $monitor.Monitor.Left -and $windowRect.Top -eq $monitor.Monitor.Top -and
        $windowRect.Right -eq $monitor.Monitor.Right -and $windowRect.Bottom -eq $monitor.Monitor.Bottom
    $clientFillsMonitor = ($clientRect.Right - $clientRect.Left) -eq ($monitor.Monitor.Right - $monitor.Monitor.Left) -and
        ($clientRect.Bottom - $clientRect.Top) -eq ($monitor.Monitor.Bottom - $monitor.Monitor.Top)
    $captionAbsent = ($style -band 0x00C00000) -eq 0
} finally {
    if ($previousDpi -ne [IntPtr]::Zero) { [void][RoadsterReleaseWindow]::SetThreadDpiAwarenessContext($previousDpi) }
}
$closeSent = $process.CloseMainWindow()
if (-not $closeSent) { throw 'Normal main-window close could not be sent.' }
if (-not $process.WaitForExit(15000)) {
    $process.Kill()
    throw 'Standalone EXE failed to exit after normal window close.'
}
$stdout = $stdoutTask.GetAwaiter().GetResult()
$stderr = $stderrTask.GetAwaiter().GetResult()
[IO.File]::WriteAllText((Join-Path $qaRoot 'release.stdout.log'), $stdout)
[IO.File]::WriteAllText((Join-Path $qaRoot 'release.stderr.log'), $stderr)
$result = [ordered]@{
    executable = $start.FileName
    sha256 = (Get-FileHash -LiteralPath $start.FileName -Algorithm SHA256).Hash.ToLowerInvariant()
    window_created = $windowFound
    startup_fills_monitor = $fillsMonitor
    client_fills_monitor = $clientFillsMonitor
    title_bar_absent = $captionAbsent
    window_bounds = $windowRect
    monitor_bounds = $monitor.Monitor
    normal_close_sent = $closeSent
    exit_code = $process.ExitCode
    stderr_bytes = [Text.Encoding]::UTF8.GetByteCount($stderr)
}
$process.Dispose()
$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $qaRoot 'release-check.json') -Encoding utf8
if ($result.exit_code -ne 0 -or $stderr.Length -ne 0 -or $stdout -match '(?i)\b(?:ERROR|Parse Error|Script Error)\b') {
    throw 'Standalone EXE reported errors; inspect release logs.'
}
if (-not $fillsMonitor -or -not $clientFillsMonitor -or -not $captionAbsent) {
    throw 'Standalone startup did not cover the whole monitor without a title bar.'
}
$result | ConvertTo-Json
