# Copyright (c) 2026 ready-4-it
# HUD settings module loader (core → dialogs → update → about meta only).
# This tree is owned by the VS Code extension. Do not load sibling r4it_ai_keep_clean_ccc plugin paths from here.
# Tab partials (about/help/activation) are dot-sourced inside Show-SettingsPanel.
#
# Weiche: skip missing files. Must stay at script scope — a function that
# dot-sources would hide Get-CccAboutPackageVersion / New-HudScrollPage
# after it returns (Cursor + VS Code HUD both break).

$script:HudSettingsRoot = $PSScriptRoot
$script:HudScriptRoot = Split-Path $PSScriptRoot -Parent

$gatePs1 = Join-Path $script:HudScriptRoot 'hud-gate.ps1'
if (Test-Path -LiteralPath $gatePs1) { . $gatePs1 }

foreach ($rel in @(
    '_state.ps1',
    'core\host-identity.ps1',
    'core\copy-scope.ps1',
    'core\weichen.ps1',
    'core\scroll-layout.ps1',
    'core\topmost.ps1',
    'core\modal-shell.ps1',
    'dialogs\zebra-consent.ps1',
    'dialogs\message-box.ps1',
    'dialogs\settings-error.ps1',
    'update\build-display.ps1',
    'update\async-node.ps1',
    'update\check-result.ps1',
    'update\apply-result.ps1',
    'about\resolve-meta.ps1',
    'preview\marker-bitmap.ps1',
    'backup\hud-bundle.ps1'
  )) {
  $p = Join-Path $PSScriptRoot $rel
  if (Test-Path -LiteralPath $p) { . $p }
}

