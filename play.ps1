param([string]$Godot = $env:GODOT)
$ErrorActionPreference = 'Stop'
if (-not $Godot) {
    $bundledEngine = Join-Path $PSScriptRoot 'build\tools\godot-4.4.1\Godot_v4.4.1-stable_win64.exe'
    if (Test-Path -LiteralPath $bundledEngine) { $Godot = $bundledEngine }
    else { $Godot = (Get-Command godot -ErrorAction Stop).Source }
}
& $Godot --path $PSScriptRoot
exit $LASTEXITCODE
