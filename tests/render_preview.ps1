param([string]$Godot = $env:GODOT)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
    $bundledEngine = Join-Path $projectRoot 'build\tools\godot-4.4.1\Godot_v4.4.1-stable_win64_console.exe'
    if (Test-Path -LiteralPath $bundledEngine) { $Godot = $bundledEngine }
    else { $Godot = (Get-Command godot -ErrorAction Stop).Source }
}
$previewRoot = Join-Path $projectRoot 'build\previews'
New-Item -ItemType Directory -Path $previewRoot -Force | Out-Null
$stdoutPath = Join-Path $previewRoot 'render.stdout.log'
$stderrPath = Join-Path $previewRoot 'render.stderr.log'
$engineLog = Join-Path $previewRoot 'render.engine.log'
$engineArgs = @('--path', ('"' + $projectRoot + '"'), '--log-file', ('"' + $engineLog + '"'), '--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3', '--audio-driver', 'Dummy', '--resolution', '1280x720', '--position', '-1800,-900', '-s', 'tests/preview_hunt.gd')
$process = Start-Process -FilePath $Godot -ArgumentList $engineArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
if (-not $process.WaitForExit(60000)) {
    $process.Kill()
    throw 'Graphical preview timed out after 60 seconds.'
}
$output = (Get-Content -LiteralPath $stdoutPath, $stderrPath -Raw -ErrorAction SilentlyContinue) -join "`n"
Write-Output $output
if ($process.ExitCode -ne 0 -or $output -match 'SCRIPT ERROR|Parse Error|Compile Error') {
    throw "Graphical preview failed (exit $($process.ExitCode))."
}
Write-Output "Game screenshots saved in $previewRoot"
