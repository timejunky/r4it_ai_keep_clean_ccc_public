# Copyright (c) 2026 ready-4-it
# Cursor dock weiche — window-title and process predicates for the Cursor Agents host.
# Job: identify Cursor Agents windows and map Cursor process names to the 'cursor' host ID.
# Caller: weichen/dock/index.ps1

function Test-IsCursorAgentsTitle([string]$t) {
  if ([string]::IsNullOrWhiteSpace($t)) { return $false }
  $trim = $t.Trim()
  # VS Code / VSCodium / Antigravity must never match as Cursor
  if ($trim -like '*Visual Studio Code*' -and $trim -notmatch '^Cursor') { return $false }
  if ($trim -like '*VSCodium*') { return $false }
  if ($trim -like '*Antigravity*') { return $false }
  if ($trim -eq 'Cursor Agents') { return $true }
  if ($trim -match '^Cursor Agents(\s*[—\-:].*)?$') { return $true }
  # Bare "Agents" or "Agents — …" is ambiguous; resolved via process name in the caller.
  return $false
}

function Get-CursorHostFromProcess([string]$name) {
  if ($name -eq 'Cursor') { return 'cursor' }
  return $null
}

function Get-CursorHostFromTitle([string]$t) {
  if ([string]::IsNullOrWhiteSpace($t)) { return $null }
  if ($t.Trim() -like 'Cursor Agents*') { return 'cursor' }
  return $null
}
