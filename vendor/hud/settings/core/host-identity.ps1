# Copyright (c) 2026 ready-4-it
# Shared HUD runtime identity (version · Agent|IDE · derivative).
# Safe to dot-source from the pill before settings load.

function Get-HudDerivativeFromProcessName([string]$name) {
  if ([string]::IsNullOrWhiteSpace($name)) { return $null }
  $n = $name.Trim()
  if ($n -like '*.exe') { $n = $n.Substring(0, $n.Length - 4) }
  $low = $n.ToLowerInvariant()
  if ($low -eq 'cursor') { return 'cursor' }
  if ($low -eq 'antigravity' -or $low -like '*antigravity*') { return 'antigravity' }
  if ($low -eq 'code - insiders' -or $low -eq 'code-insiders') { return 'vscode-insiders' }
  if ($low -eq 'code' -or $low -eq 'code - oss') { return 'vscode' }
  return $null
}

function Get-HudDerivativeLabel([string]$id) {
  switch ([string]$id) {
    'cursor' { return 'Cursor' }
    'vscode-insiders' { return 'VS Code Insiders' }
    'vscode' { return 'VS Code' }
    'antigravity' { return 'Antigravity' }
    default { return 'Unknown' }
  }
}

function Get-HudRuntimeIdentity {
  $deriv = ''
  if ($script:sidebarHost) { $deriv = [string]$script:sidebarHost }
  if (-not $deriv -and $script:scopeHost) { $deriv = [string]$script:scopeHost }
  if (-not $deriv) {
    try {
      $focusPath = Join-Path $env:USERPROFILE '.cursor\ccc-hud-focus-host.json'
      if (Test-Path -LiteralPath $focusPath) {
        $j = (Get-Content -LiteralPath $focusPath -Raw -Encoding UTF8) | ConvertFrom-Json
        $deriv = [string]$j.host
      }
    } catch { }
  }
  if (-not $deriv -and (Get-Command Get-AgentsHostFromHwnd -ErrorAction SilentlyContinue)) {
    try {
      if ($script:agentsHwnd -and $script:agentsHwnd -ne [IntPtr]::Zero) {
        $deriv = [string](Get-AgentsHostFromHwnd $script:agentsHwnd)
      }
    } catch { }
  }
  if ($deriv -eq 'code') { $deriv = 'vscode' }
  if ($deriv -ne 'cursor' -and $deriv -ne 'vscode' -and $deriv -ne 'vscode-insiders' -and $deriv -ne 'antigravity') {
    $deriv = ''
  }

  $surface = 'IDE'
  $agentsTitle = $false
  try {
    if ($script:agentsHwnd -and $script:agentsHwnd -ne [IntPtr]::Zero -and (Get-Command Test-IsAgentsWindowTitle -ErrorAction SilentlyContinue)) {
      $sb = New-Object System.Text.StringBuilder 512
      [void][CccHudWin]::GetWindowText($script:agentsHwnd, $sb, 512)
      $agentsTitle = [bool](Test-IsAgentsWindowTitle $sb.ToString())
    }
  } catch { }
  if ($agentsTitle -or $script:sidebarHost -or ($deriv -and $script:agentsHwnd -and $script:agentsHwnd -ne [IntPtr]::Zero)) {
    $surface = 'Agent'
  }

  $version = ''
  if (Get-Command Get-CccVersion -ErrorAction SilentlyContinue) {
    try { $version = [string](Get-CccVersion) } catch { }
  }
  if (-not $version -and (Get-Command Get-CccHudBuildDisplay -ErrorAction SilentlyContinue)) {
    try { $version = [string](Get-CccHudBuildDisplay) } catch { }
  }
  if (-not $version) {
    try {
      $idPath = Join-Path $env:USERPROFILE '.cursor\ccc-hud-identity.json'
      if (-not (Test-Path -LiteralPath $idPath)) {
        $walk = $PSScriptRoot
        for ($i = 0; $i -lt 6 -and $walk; $i++) {
          $cand = Join-Path $walk 'ccc-hud-identity.json'
          if (Test-Path -LiteralPath $cand) { $idPath = $cand; break }
          $walk = Split-Path -Parent $walk
        }
      }
      if (Test-Path -LiteralPath $idPath) {
        $id = (Get-Content -LiteralPath $idPath -Raw -Encoding UTF8) | ConvertFrom-Json
        $version = if ($id.display) { [string]$id.display } else { [string]$id.version }
      }
    } catch { }
  }
  if ([string]::IsNullOrWhiteSpace($version)) { $version = '0.0.0' }

  $rootHint = @([string]$PSScriptRoot, [string]$script:HudScriptRoot) -join '|'
  $channel = 'Plugin'
  if ($rootHint -match '(?i)r4it_ai_keep_clean_ccc_vs|akc-ccc-vs|vscode-agent-plugin|\\extension\\(hud|agent-plugin)') {
    $channel = 'Extension'
  } elseif ($rootHint -match '(?i)globalStorage') {
    $channel = 'Extension'
  } elseif ($rootHint -match '(?i)plugins[\\/]local|cursor-plugin|r4it_ai_keep_clean_ccc') {
    $channel = 'Plugin'
  }

  $derivLabel = Get-HudDerivativeLabel $deriv
  $tierRaw = if ($script:hudTier) { [string]$script:hudTier } else { 'none' }
  $editionLabel = switch ($tierRaw.ToLowerInvariant()) {
    'full' { 'Pro' }
    'pro' { 'Pro' }
    'trial' { 'Trial' }
    default { 'Free' }
  }
  return [pscustomobject]@{
    Version        = $version
    Surface        = $surface
    Channel        = $channel
    DerivativeId   = $(if ($deriv) { $deriv } else { 'unknown' })
    Derivative     = $derivLabel
    Edition        = $tierRaw
    Footer         = "$version · $editionLabel · $surface · $derivLabel · $channel"
  }
}
