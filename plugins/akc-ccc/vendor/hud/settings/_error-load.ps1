# Copyright (c) 2026 ready-4-it
# Minimal stack for settings-failure UI (pill catch path). Script-scope only.
# Extension-owned copy — no sibling plugin paths.

$script:HudSettingsRoot = $PSScriptRoot
if (-not $script:HudScriptRoot) { $script:HudScriptRoot = Split-Path $PSScriptRoot -Parent }

foreach ($rel in @(
    'core\host-identity.ps1',
    'core\weichen.ps1',
    'core\topmost.ps1',
    'core\modal-shell.ps1',
    'dialogs\message-box.ps1',
    'dialogs\settings-error.ps1'
  )) {
  $p = Join-Path $PSScriptRoot $rel
  if (Test-Path -LiteralPath $p) { . $p }
}

