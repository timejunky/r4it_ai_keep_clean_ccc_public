# Copyright (c) 2026 ready-4-it
# HUD message box (metal buttons).

function Resolve-HudMessageBoxFooter {
  param([string]$Footer = '')
  if (-not [string]::IsNullOrWhiteSpace($Footer)) { return [string]$Footer }
  if (Get-Command Get-HudRuntimeIdentity -ErrorAction SilentlyContinue) {
    try {
      $id = Get-HudRuntimeIdentity
      if ($id -and $id.Footer) { return [string]$id.Footer }
    } catch { }
  }
  if (Get-Command Get-HudSettingsFailFooter -ErrorAction SilentlyContinue) {
    try {
      $fb = Get-HudSettingsFailFooter
      if (-not [string]::IsNullOrWhiteSpace($fb)) { return [string]$fb }
    } catch { }
  }
  return '0.0.0 · ? · Unknown · ?'
}

function Show-HudMessageBox {
  param(
    [Parameter(Mandatory)][string]$Text,
    [string]$Caption = 'CCC Update',
    [string]$Footer = '',
    [System.Windows.Forms.MessageBoxButtons]$Buttons = [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information
  )
  $Footer = Resolve-HudMessageBoxFooter $Footer
  $sc = Get-HudModalScale
  $th = if ($script:HudTheme) { $script:HudTheme } else { Get-HudTheme }
  $pad = [int](16 * $sc)
  $innerW = [int](420 * $sc)
  $textH = [int](120 * $sc)
  if (Get-Command Measure-HudWrap -ErrorAction SilentlyContinue) {
    $textH = [Math]::Min([int](260 * $sc), ([Math]::Max([int](72 * $sc), (Measure-HudWrap -Text $Text -Font (New-HudFont 'Segoe UI' ([float](9 * $sc))) -MaxWidth $innerW) + [int](12 * $sc))))
  }
  $btnRowH = [int](36 * $sc)
  $clientH = $pad + $textH + [int](16 * $sc) + $btnRowH + $pad
  $shell = New-HudModalShell -Title $Caption -ClientSize (New-Object System.Drawing.Size(($innerW + (2 * $pad)), $clientH))
  $f = $shell.Form

  $lbl = New-HudLabel -Text $Text -Fore $th.TextPrimary -Font (New-HudFont 'Segoe UI' ([float](9 * $sc)))
  $lbl.AutoSize = $false
  $lbl.Location = New-Object System.Drawing.Point($pad, $pad)
  $lbl.Size = New-Object System.Drawing.Size($innerW, $textH)
  $f.Controls.Add($lbl)

  $btnY = $f.ClientSize.Height - $pad - $btnRowH
  $isYesNo = ($Buttons -eq [System.Windows.Forms.MessageBoxButtons]::YesNo)
  if ($isYesNo) {
    $txtNo = 'No'
    $txtYes = 'Yes'
    if (Get-Command Get-HudT -ErrorAction SilentlyContinue) {
      $candNo = Get-HudT 'common.no'
      if ($candNo -and $candNo -ne 'common.no') { $txtNo = $candNo }
      $candYes = Get-HudT 'common.yes'
      if ($candYes -and $candYes -ne 'common.yes') { $txtYes = $candYes }
    }
    $btnNo = New-HudMetalButton -Text $txtNo -Width ([int](96 * $sc)) -Height $btnRowH -Theme $th -FixedWidth -KeepCase
    $btnNo.Location = New-Object System.Drawing.Point(($f.ClientSize.Width - $pad - $btnNo.Width), $btnY)
    $btnNo.DialogResult = [System.Windows.Forms.DialogResult]::No
    $f.Controls.Add($btnNo)
    $f.CancelButton = $btnNo

    $btnYes = New-HudMetalButton -Text $txtYes -Width ([int](96 * $sc)) -Height $btnRowH -Theme $th -Primary -FixedWidth -KeepCase
    $btnYes.Location = New-Object System.Drawing.Point(($btnNo.Left - ([int](10 * $sc)) - $btnYes.Width), $btnY)
    $btnYes.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $f.Controls.Add($btnYes)
    $f.AcceptButton = $btnYes
  } else {
    $btnOk = New-HudMetalButton -Text 'OK' -Width ([int](96 * $sc)) -Height $btnRowH -Theme $th -Primary -FixedWidth -KeepCase
    $btnOk.Location = New-Object System.Drawing.Point(($f.ClientSize.Width - $pad - $btnOk.Width), $btnY)
    $btnOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $f.Controls.Add($btnOk)
    $f.AcceptButton = $btnOk
    $f.CancelButton = $btnOk
  }

  $btnLeft = if ($isYesNo) { $btnYes.Left } else { $btnOk.Left }
  $lblFoot = New-HudLabel -Text $Footer -Fore $th.TextMuted -Font (New-HudFont 'Segoe UI' ([float](8 * $sc)))
  $lblFoot.AutoSize = $false
  $lblFoot.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
  $lblFoot.Location = New-Object System.Drawing.Point($pad, $btnY)
  $lblFoot.Size = New-Object System.Drawing.Size([Math]::Max(40, ($btnLeft - $pad - ([int](10 * $sc)))), $btnRowH)
  $f.Controls.Add($lblFoot)

  $owner = $shell.Owner
  return [string](Invoke-HudModalShell -Shell $shell -ShowDialog {
    if ($owner -and -not $owner.IsDisposed) {
      return $f.ShowDialog($owner)
    }
    return $f.ShowDialog()
  })
}
