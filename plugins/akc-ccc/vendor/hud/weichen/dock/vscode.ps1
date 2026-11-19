# Copyright (c) 2026 ready-4-it
# VS Code dock weiche — window-title and process predicates for the VS Code Agents host.
# Job: identify VS Code / VSCodium Agents windows and map Code process names to 'vscode'.
# Caller: weichen/dock/index.ps1

function Test-IsVsCodeAgentsTitle([string]$t) {
  if ([string]::IsNullOrWhiteSpace($t)) { return $false }
  $trim = $t.Trim()
  if ($trim -eq 'VS Code Agents') { return $true }
  if ($trim -match '^VS Code Agents(\s*[—\-:].*)?$') { return $true }
  if ($trim -match '^Visual Studio Code.*Agents$') { return $true }
  # "Visual Studio Code — Agents" style
  if ($trim -like '*Visual Studio Code*' -and $trim -match 'Agents') { return $true }
  return $false
}

function Get-VsCodeHostFromProcess([string]$name) {
  if ($name -eq 'Code' -or $name -eq 'Code - Insiders') { return 'vscode' }
  return $null
}

function Get-VsCodeHostFromTitle([string]$t) {
  if ([string]::IsNullOrWhiteSpace($t)) { return $null }
  $trim = $t.Trim()
  if ($trim -like 'Visual Studio Code*') { return 'vscode' }
  if ($trim -like 'VS Code Agents*') { return 'vscode' }
  return $null
}
