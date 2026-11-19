# Copyright (c) 2026 ready-4-it
# Antigravity dock weiche — window predicates for the Antigravity Agents host.
# Job: identify Antigravity agent windows (NOT the IDE editor) and map Antigravity process to 'antigravity'.
# Caller: weichen/dock/index.ps1

# Antigravity agent window: bare "Antigravity" or the chat/workspace title.
# The editor ("… - Antigravity IDE - file") is not a dock target.
function Test-IsAntigravityAgentWindow([string]$title, [string]$hostId) {
  if ($hostId -ne 'antigravity') { return $false }
  if ([string]::IsNullOrWhiteSpace($title)) { return $false }
  # Editor: "folder - Antigravity IDE - file.py"
  if ($title -like '*Antigravity IDE*') { return $false }
  return $true
}

function Test-IsAntigravityAgentsTitle([string]$t) {
  if ([string]::IsNullOrWhiteSpace($t)) { return $false }
  $trim = $t.Trim()
  # Editor windows ("… - Antigravity IDE - file") are never the agent surface.
  if ($trim -like '*Antigravity IDE*' -or $trim -eq 'Antigravity IDE') { return $false }
  if ($trim -eq 'Antigravity') { return $true }
  if ($trim -eq 'Antigravity Agents') { return $true }
  if ($trim -match '^Antigravity Agents(\s*[—\-:].*)?$') { return $true }
  return $false
}

function Get-AntigravityHostFromProcess([string]$name) {
  if ($name -like 'Antigravity*' -or $name -eq 'Antigravity' -or $name -eq 'Antigravity IDE') { return 'antigravity' }
  return $null
}

function Get-AntigravityHostFromTitle([string]$t) {
  if ([string]::IsNullOrWhiteSpace($t)) { return $null }
  if ($t.Trim() -like 'Antigravity Agents*') { return 'antigravity' }
  return $null
}
