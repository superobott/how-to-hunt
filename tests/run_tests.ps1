param(
    [string]$Godot = $env:GODOT,
    [ValidateSet('all', 'unit', 'movement', 'hunting', 'survival', 'ui', 'vehicles', 'coop')][string]$Suite = 'all',
    [switch]$VerboseEngine,
    [ValidateRange(1, 900)][int]$TimeoutSeconds = 180
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
    $bundledEngine = Join-Path $projectRoot 'build\tools\godot-4.4.1\Godot_v4.4.1-stable_win64_console.exe'
    if (Test-Path -LiteralPath $bundledEngine) { $Godot = $bundledEngine }
    else { $Godot = (Get-Command godot -ErrorAction Stop).Source }
}
$logRoot = Join-Path $projectRoot 'build\test-results'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

function Invoke-GodotSuite([string]$Name, [string[]]$SuiteArgs) {
    $stdoutPath = Join-Path $logRoot "$Name.stdout.log"
    $stderrPath = Join-Path $logRoot "$Name.stderr.log"
    $engineLog = Join-Path $logRoot "$Name.engine.log"
    $engineArgs = @('--headless', '--path', ('"' + $projectRoot + '"'), '--log-file', ('"' + $engineLog + '"')) + $SuiteArgs
    if ($VerboseEngine) { $engineArgs += '--verbose' }
    $engineArgs += @('--', '--offline-tests')
    $process = Start-Process -FilePath $Godot -ArgumentList $engineArgs -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill()
        throw "$Name timed out after $TimeoutSeconds seconds. See $logRoot"
    }
    $output = (Get-Content -LiteralPath $stdoutPath, $stderrPath -Raw -ErrorAction SilentlyContinue) -join "`n"
    Write-Output $output
    if ($process.ExitCode -ne 0 -or $output -match 'SCRIPT ERROR|Parse Error|Compile Error') {
        throw "$Name failed (exit $($process.ExitCode)). See $logRoot"
    }
    Write-Output "$Name passed."
}

if ($Suite -eq 'all') { Invoke-GodotSuite 'import' @('--import') }
if ($Suite -in @('all', 'unit')) { Invoke-GodotSuite 'unit' @('-s', 'tests/run_tests.gd') }
if ($Suite -in @('all', 'movement')) { Invoke-GodotSuite 'movement' @('--fixed-fps', '60', '-s', 'tests/smoke_world.gd') }
if ($Suite -in @('all', 'hunting')) { Invoke-GodotSuite 'hunting' @('--fixed-fps', '60', '-s', 'tests/smoke_hunt.gd') }
if ($Suite -in @('all', 'survival')) { Invoke-GodotSuite 'survival' @('--fixed-fps', '60', '-s', 'tests/smoke_survival.gd') }
if ($Suite -in @('all', 'ui')) { Invoke-GodotSuite 'ui' @('--fixed-fps', '60', '-s', 'tests/smoke_ui.gd') }
if ($Suite -in @('all', 'vehicles')) { Invoke-GodotSuite 'vehicles' @('--fixed-fps', '60', '-s', 'tests/smoke_vehicles.gd') }
if ($Suite -in @('all', 'coop')) {
    & (Join-Path $PSScriptRoot 'run_coop.ps1') -Godot $Godot
    & (Join-Path $PSScriptRoot 'run_coop.ps1') -Godot $Godot -Silence
}
Write-Output 'Requested game checks passed.'
