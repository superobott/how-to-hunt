param([string]$Godot = $env:GODOT, [int]$Port = 28741, [switch]$Silence)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Godot) { $Godot = Join-Path $projectRoot 'build/tools/godot-4.4.1/Godot_v4.4.1-stable_win64_console.exe' }
$logs = Join-Path $projectRoot 'build/test-results'
if ($Silence) { $logs = Join-Path $logs 'coop-silence' }
New-Item -ItemType Directory -Force $logs | Out-Null
$processes = @()
try {
    foreach ($slot in 0..3) {
        $role = if ($slot -eq 0) { 'host' } else { 'guest' }
        $arguments = @('--headless', '--path', ('"' + $projectRoot + '"'), '-s', 'tests/smoke_coop.gd', '--', '--offline-tests', "--role=$role", "--slot=$slot", "--port=$Port")
        if ($Silence) { $arguments += '--silence' }
        $processes += Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput "$logs/coop-$slot.stdout.log" -RedirectStandardError "$logs/coop-$slot.stderr.log"
        if ($slot -eq 0) {
            $readyDeadline = [DateTime]::UtcNow.AddSeconds(30)
            while (-not (Select-String -LiteralPath "$logs/coop-0.stdout.log" -Pattern 'READY host' -Quiet)) {
                if ($processes[0].HasExited -or [DateTime]::UtcNow -gt $readyDeadline) { throw 'Co-op host did not start.' }
                Start-Sleep -Milliseconds 250
            }
        }
    }
    $deadline = [DateTime]::UtcNow.AddSeconds(70)
    while (@($processes | Where-Object { -not $_.HasExited }).Count -gt 0) {
        if ([DateTime]::UtcNow -gt $deadline) { throw 'Co-op integration timed out.' }
        Start-Sleep -Milliseconds 250
    }
    $failed = $false
    foreach ($slot in 0..3) {
        $output = (Get-Content "$logs/coop-$slot.stdout.log", "$logs/coop-$slot.stderr.log" -Raw) -join "`n"
        Write-Output $output
        if ($processes[$slot].ExitCode -ne 0 -or $output -match 'SCRIPT ERROR|Parse Error|Compile Error|FAIL |above the MTU' -or $output -notmatch 'COOP COMPLETE .* 0 failures') { $failed = $true }
    }
    if ($failed) { throw 'Co-op integration failed. See build/test-results/coop-*.log' }
    Write-Output 'Four-player co-op integration passed.'
} finally {
    foreach ($process in $processes) { if (-not $process.HasExited) { $process.Kill() } }
}
