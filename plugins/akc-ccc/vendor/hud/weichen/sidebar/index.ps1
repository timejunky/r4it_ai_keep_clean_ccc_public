# Copyright (c) 2026 ready-4-it
# Host weiche for Agents sidebar scrape. Cursor and VS Code never share adapters.

. (Join-Path $PSScriptRoot 'vscode.ps1')
. (Join-Path $PSScriptRoot 'cursor.ps1')
. (Join-Path $PSScriptRoot 'antigravity.ps1')

function Ensure-HudUiaAssemblies {
  if ($script:uiaReady) { return }
  try {
    Add-Type -AssemblyName UIAutomationClient
    Add-Type -AssemblyName UIAutomationTypes
    $script:uiaReady = $true
  } catch {
    $script:uiaReady = $false
  }
}

function Invoke-HudSidebarWeiche($root, [string]$hostId) {
  if ($hostId -eq 'vscode') { return Get-VsCodeSidebarLabel $root }
  return Get-CursorSidebarLabel $root
}
