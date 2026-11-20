param([switch]$Watch)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$engine = Join-Path $PSScriptRoot 'build\tools\godot-4.4.1\Godot_v4.4.1-stable_win64.exe'
if (-not (Test-Path $engine)) { throw 'Run this generator on the development machine with the bundled Godot engine.' }
function Build-Game {
    $env:TEMP = Join-Path $PSScriptRoot 'build\temp'
    $env:TMP = $env:TEMP
    New-Item -ItemType Directory -Force $env:TEMP | Out-Null
    $out = Join-Path $PSScriptRoot 'build\release'
    New-Item -ItemType Directory -Force $out | Out-Null
    & ($engine.Replace(".exe", "_console.exe")) --headless --path $PSScriptRoot --import
    if ($LASTEXITCODE -ne 0) { throw 'Import failed' }
    & ($engine.Replace(".exe", "_console.exe")) --headless --path $PSScriptRoot --export-pack 'Windows Portable' "$out\How to Hunt.pck"
    if ($LASTEXITCODE -ne 0) { throw 'Packaging failed' }
    Copy-Item -LiteralPath $engine -Destination "$out\How to Hunt.exe" -Force
    'Extract the entire ZIP, then open How to Hunt.exe. Keep the PCK beside the EXE. WASD move; E shop; V cycle owned vehicles; Space/Ctrl airplane altitude.' | Set-Content "$out\READ ME.txt"
    Compress-Archive -Path "$out\*" -DestinationPath 'build\How-to-Hunt-Windows.zip' -Force
    Write-Host 'Ready: build\How-to-Hunt-Windows.zip'
}
function Source-Stamp {
    (Get-ChildItem scripts,data,scenes,shaders,project.godot,export_presets.cfg -Recurse -File | Where-Object Extension -ne '.uid' | ForEach-Object { "$($_.FullName):$($_.LastWriteTimeUtc.Ticks):$($_.Length)" }) -join '|'
}
Build-Game
if ($Watch) {
    $previous = Source-Stamp
    Write-Host 'Watching source files. Ctrl+C stops.'
    while ($true) {
        Start-Sleep -Seconds 2
        $current = Source-Stamp
        if ($current -ne $previous) {
            Start-Sleep -Seconds 1
            try { Build-Game; $previous = $current } catch { Write-Warning $_ }
        }
    }
}
