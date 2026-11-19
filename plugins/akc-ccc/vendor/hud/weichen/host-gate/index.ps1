# Copyright (c) 2026 ready-4-it
# HUD host-gate weiche. After VS Deactivate, do not dock on Code.exe.

function Read-HudHostGate {
  $path = Join-Path $env:USERPROFILE '.cursor\ccc-hud-host-gate.json'
  $gate = [ordered]@{ hud = $true; vscode = $true; cursor = $true; antigravity = $true }
  if (-not (Test-Path -LiteralPath $path)) { return $gate }
  try {
    $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -ne $raw.hud) { $gate.hud = [bool]$raw.hud }
    if ($null -ne $raw.vscode) { $gate.vscode = [bool]$raw.vscode }
    if ($null -ne $raw.cursor) { $gate.cursor = [bool]$raw.cursor }
    if ($null -ne $raw.antigravity) { $gate.antigravity = [bool]$raw.antigravity }
    if (-not $gate.hud) { $gate.vscode = $false; $gate.cursor = $false; $gate.antigravity = $false }
  } catch { }
  return $gate
}

function Test-HudHostEnabled([string]$hostId) {
  $gate = Read-HudHostGate
  if (-not $gate.hud) { return $false }
  if ([string]::IsNullOrWhiteSpace($hostId)) { return [bool]$gate.hud }
  if ($hostId -eq 'vscode') { return [bool]$gate.vscode }
  if ($hostId -eq 'cursor') { return [bool]$gate.cursor }
  if ($hostId -eq 'antigravity') { return [bool]$gate.antigravity }
  return [bool]$gate.hud
}
