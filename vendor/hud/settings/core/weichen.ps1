# Copyright (c) 2026 ready-4-it
# Soft guards: never call instance methods on $null (WinForms wiring).

function Add-HudClick {
  param($Control, [scriptblock]$Handler)
  if ($null -eq $Control) { return }
  $Control.Add_Click($Handler)
}

function Add-HudValueChanged {
  param($Control, [scriptblock]$Handler)
  if ($null -eq $Control) { return }
  $Control.Add_ValueChanged($Handler)
}

function Add-HudLeave {
  param($Control, [scriptblock]$Handler)
  if ($null -eq $Control) { return }
  $Control.Add_Leave($Handler)
}

function Add-HudSelectedIndexChanged {
  param($Control, [scriptblock]$Handler)
  if ($null -eq $Control) { return }
  $Control.Add_SelectedIndexChanged($Handler)
}

function Add-HudCheckedChanged {
  param($Control, [scriptblock]$Handler)
  if ($null -eq $Control) { return }
  $Control.Add_CheckedChanged($Handler)
}
