# Copyright (c) 2026 ready-4-it
# Top-most suspend/resume for settings + child modals.

function Suspend-HudSettingsTopMost {
  if ($script:hudSettingsTopMostSuspended) { return }
  $script:hudSettingsTopMostSuspended = $true
  if ($null -ne $script:settingsParkForm -and -not $script:settingsParkForm.IsDisposed) {
    try { [CccHudWin]::ClearUnownedTopMost($script:settingsParkForm.Handle) } catch { }
  }
  if ($null -ne $script:settingsDlg -and -not $script:settingsDlg.IsDisposed) {
    try {
      [CccHudWin]::ClearUnownedTopMost($script:settingsDlg.Handle)
      $script:settingsDlg.TopMost = $false
    } catch { }
  }
}

function Resume-HudSettingsTopMost {
  if (-not $script:hudSettingsTopMostSuspended) { return }
  $script:hudSettingsTopMostSuspended = $false
  if ($null -ne $script:settingsParkForm -and -not $script:settingsParkForm.IsDisposed) {
    try { [CccHudWin]::ShowUnownedTopMost($script:settingsParkForm.Handle) } catch { }
  }
  if ($null -ne $script:settingsDlg -and -not $script:settingsDlg.IsDisposed) {
    try {
      [CccHudWin]::ShowUnownedTopMost($script:settingsDlg.Handle)
      $script:settingsDlg.TopMost = $true
    } catch { }
  }
}

function Invoke-HudOwnedFileDialog {
  param(
    [Parameter(Mandatory)]$Dialog,
    [System.Windows.Forms.IWin32Window]$Owner = $null
  )
  $owner = $Owner
  if ($null -eq $owner -and $null -ne $script:settingsDlg -and -not $script:settingsDlg.IsDisposed) {
    $owner = $script:settingsDlg
  }
  # Settings and its park form are HWND_TOPMOST. A common dialog then opens behind them.
  Suspend-HudSettingsTopMost
  try {
    if ($owner) { return $Dialog.ShowDialog($owner) }
    return $Dialog.ShowDialog()
  } finally {
    Resume-HudSettingsTopMost
  }
}

function Set-HudChildModalTopMost {
  param($ChildForm)
  if ($null -eq $ChildForm) { return }
  try {
    [CccHudWin]::ShowUnownedTopMost($ChildForm.Handle)
    $ChildForm.BringToFront()
    [void]$ChildForm.Activate()
  } catch { }
}
