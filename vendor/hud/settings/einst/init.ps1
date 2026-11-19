# Copyright (c) 2026 ready-4-it
# Einstellungen tab builder — dot-sourced inside Show-SettingsPanel (keeps closure scope).

foreach ($__einstPart in @(
    'top-bottom.ps1',
    'box-card.ps1',
    'inspector-card.ps1',
    'icon-card.ps1'
  )) {
  $__einstFile = Join-Path $PSScriptRoot $__einstPart
  if (-not (Test-Path -LiteralPath $__einstFile)) {
    throw "Einstellungen module missing: $__einstFile"
  }
  . $__einstFile
}
