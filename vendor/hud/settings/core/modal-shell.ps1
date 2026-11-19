# Copyright (c) 2026 ready-4-it
# Reusable fixed-dialog shell for HUD child modals (message box, consent, …).

function Get-HudModalScale {
  if ($null -ne $scale -and [double]$scale -gt 0) { return [double]$scale }
  return 1.0
}

function New-HudModalShell {
  param(
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][System.Drawing.Size]$ClientSize,
    [System.Windows.Forms.Form]$Owner = $null
  )
  $th = if ($script:HudTheme) { $script:HudTheme } else { Get-HudTheme }
  $sc = Get-HudModalScale
  $owner = if ($Owner -and -not $Owner.IsDisposed) { $Owner } else { $script:settingsDlg }
  $f = New-Object System.Windows.Forms.Form
  $f.Text = $Title
  $f.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
  $f.MaximizeBox = $false
  $f.MinimizeBox = $false
  $f.ShowInTaskbar = $false
  $f.StartPosition = if ($owner) { [System.Windows.Forms.FormStartPosition]::CenterParent } else { [System.Windows.Forms.FormStartPosition]::CenterScreen }
  $f.BackColor = [System.Drawing.Color]::FromArgb(28, 32, 40)
  $f.ClientSize = $ClientSize
  $f.TopMost = $true
  if ($owner -and -not $owner.IsDisposed) { $f.Owner = $owner }
  return @{
    Form   = $f
    Theme  = $th
    Scale  = $sc
    Owner  = $owner
    Pad    = [int](16 * $sc)
  }
}

function Invoke-HudModalShell {
  param(
    [Parameter(Mandatory)][hashtable]$Shell,
    [Parameter(Mandatory)][scriptblock]$ShowDialog
  )
  $f = $Shell.Form
  $f.Add_Shown({ param($sender, $e) Set-HudChildModalTopMost $sender })
  $script:hudChildModalOpen = $true
  Suspend-HudSettingsTopMost
  try {
    return & $ShowDialog
  } finally {
    $script:hudChildModalOpen = $false
    Resume-HudSettingsTopMost
    try { $f.Dispose() } catch { }
  }
}
