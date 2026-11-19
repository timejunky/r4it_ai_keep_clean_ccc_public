# Copyright (c) 2026 ready-4-it
# AI Keep Clean CCC — Pill diagnostics: boot log, diag log, PID file.
# Job: own Write-HudBoot, Write-HudDiag, Clear-PidFile, Write-PidFile.
# Caller: winforms-pill.ps1 (dot-sourced after $bootLog, $pidPath, $cursorDir are set).

function Write-HudBoot([string]$msg) {
  try {
    $line = ((Get-Date).ToUniversalTime().ToString('o')) + ' ' + $msg
    Add-Content -LiteralPath $bootLog -Value $line -Encoding utf8
  } catch { }
}
function Write-HudDiag([string]$msg) {
  if ($env:CCC_HUD_DIAG -ne '1') { return }
  try {
    $diagLog = Join-Path $cursorDir 'ccc-hud-pill-diag.log'
    $line = ((Get-Date).ToUniversalTime().ToString('o')) + ' ' + $msg
    Add-Content -LiteralPath $diagLog -Value $line -Encoding utf8
  } catch { }
}
function Clear-PidFile {
  if (Test-Path -LiteralPath $pidPath) {
    Remove-Item -LiteralPath $pidPath -Force -ErrorAction SilentlyContinue
  }
}
function Write-PidFile {
  Set-Content -LiteralPath $pidPath -Value $PID -Encoding ascii
}