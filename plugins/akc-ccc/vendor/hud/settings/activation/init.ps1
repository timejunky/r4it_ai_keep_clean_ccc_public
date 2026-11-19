# Copyright (c) 2026 ready-4-it
# Activation tab — dot-source from Show-SettingsPanel.

$licPad = New-HudScrollPage -Parent $ui.pageLizenz
if (-not $script:hasActivationCli) {
  . (Join-Path $PSScriptRoot 'free-channel.ps1')
} else {
  . (Join-Path $PSScriptRoot 'sections.ps1')
  . (Join-Path $PSScriptRoot 'token-field.ps1')
  . (Join-Path $PSScriptRoot 'token-actions.ps1')
  . (Join-Path $PSScriptRoot 'layout.ps1')
}
