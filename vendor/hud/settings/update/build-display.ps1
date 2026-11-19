# Copyright (c) 2026 ready-4-it
# HUD build stamp from identity.

function Get-CccHudBuildDisplay {
  $root = if ($script:HudScriptRoot) { $script:HudScriptRoot } else { $PSScriptRoot }
  $cands = @(
    (Join-Path $root 'ccc-hud-identity.json'),
    (Join-Path $root '..\..\ccc-hud-identity.json')
  )
  foreach ($c in $cands) {
    try {
      $full = [System.IO.Path]::GetFullPath($c)
      if (-not (Test-Path -LiteralPath $full)) { continue }
      $j = Get-Content -LiteralPath $full -Raw -Encoding UTF8 | ConvertFrom-Json
      if ($j.display) { return [string]$j.display }
      if ($j.version) { return [string]$j.version }
    } catch { }
  }
  return 'dev'
}
