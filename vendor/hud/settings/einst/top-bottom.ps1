# Copyright (c) 2026 ready-4-it
# Einstellungen page: glass surface, transparent bottom action bar, and Top New-HudSectionPanel card.
# Dot-sourced from settings/einst/init.ps1 inside Show-SettingsPanel.

function Add-HudSubPanelHairline($panel, $theme) {
  if (-not $panel) { return }
  $panel.BackColor = [System.Drawing.Color]::FromArgb(24, 29, 38)
  Enable-HudDoubleBuffer -Control $panel
  $panel.Tag = @{ SubTheme = $theme }
  $panel.Add_Paint({
    param($s, $e)
    $r = $s.ClientRectangle
    if ($r.Width -lt 4 -or $r.Height -lt 4) { return }
    $thSub = if ($s.Tag -is [hashtable] -and $s.Tag.SubTheme) { $s.Tag.SubTheme } else { Get-HudTheme }
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(95, $thSub.BorderHairline), 1)
    $e.Graphics.DrawRectangle($pen, 0, 0, ($r.Width - 1), ($r.Height - 1))
    $pen.Dispose()
  })
}

# Shared 3-stop dark glass canvas on Einstellungen (matches About / Activation / Storage / Help)
$ui.pageEinst.BackColor = [System.Drawing.Color]::FromArgb(0x1a, 0x1c, 0x1e)
Add-HudGlassPaint -Control $ui.pageEinst -Theme $th -NoWatermark -Content

# --- Bottom Bar: transparent over glass ---
$bottom = New-Object System.Windows.Forms.Panel
$bottom.Size = New-Object System.Drawing.Size(([int](900 * $scale)), ([int](48 * $scale)))
$bottom.Location = New-Object System.Drawing.Point(([int](14 * $scale)), ([int](540 * $scale)))
$bottom.BackColor = [System.Drawing.Color]::Transparent
Enable-HudDoubleBuffer -Control $bottom
$ui.pageEinst.Controls.Add($bottom)
$ui.bottomBar = $bottom

$btnReset = New-FlatBtn (Get-HudT 'settings.reset') ([int](148 * $scale)) ([int](34 * $scale)) ([System.Drawing.Color]::FromArgb(70, 50, 50))
$bottom.Controls.Add($btnReset)

$btnApply = New-FlatBtn (Get-HudT 'settings.apply') ([int](124 * $scale)) ([int](34 * $scale)) ([System.Drawing.Color]::FromArgb(40, 110, 90))
$bottom.Controls.Add($btnApply)
$ui.btnApply = $btnApply

$btnClose = New-FlatBtn (Get-HudT 'settings.close') ([int](114 * $scale)) ([int](34 * $scale)) $bgBtn
$bottom.Controls.Add($btnClose)
$ui.btnClose = $btnClose
$dlg.CancelButton = $btnClose

# --- Top Card: Scope + Size + Style + Mode buttons inside New-HudSectionPanel ---
$top = New-HudSectionPanel -X ([int](14 * $scale)) -Y ([int](14 * $scale)) -Width ([int](900 * $scale)) -Height ([int](96 * $scale)) -Theme $th
$ui.pageEinst.Controls.Add($top)
$ui.topBar = $top

$lblScope = New-HudLabel -Text (Get-HudT 'settings.scope') -Fore $th.AccentCyan -Font (New-HudFont 'Segoe UI Semibold' ([float](9.5 * $scale)) ([System.Drawing.FontStyle]::Bold)) -AutoSize
$top.Controls.Add($lblScope)

$isPublicFree = (-not $script:hasActivationCli)
$rbProject = New-Object System.Windows.Forms.RadioButton
$rbProject.Text = Get-HudT 'settings.scope.project'
$rbProject.AutoSize = $true
$rbProject.BackColor = [System.Drawing.Color]::Transparent
$rbProject.ForeColor = $th.TextPrimary
$rbProject.Font = New-HudFont 'Segoe UI Semibold' ([float](9 * $scale))
$rbProject.Checked = (-not $isPublicFree) -and ($script:editScope -ne 'global')
$rbProject.Visible = (-not $isPublicFree)
$top.Controls.Add($rbProject)
$ui.rbProject = $rbProject

$rbGlobal = New-Object System.Windows.Forms.RadioButton
$rbGlobal.Text = Get-HudT 'settings.scope.global'
$rbGlobal.AutoSize = $true
$rbGlobal.BackColor = [System.Drawing.Color]::Transparent
$rbGlobal.ForeColor = $th.TextPrimary
$rbGlobal.Font = New-HudFont 'Segoe UI Semibold' ([float](9 * $scale))
$rbGlobal.Checked = ($script:editScope -eq 'global')
$top.Controls.Add($rbGlobal)
$ui.rbGlobal = $rbGlobal

$lblScopeHint = New-HudLabel -Text '' -Fore $th.ProGold -Font (New-HudFont 'Segoe UI' ([float](8.75 * $scale))) -AutoSize
$top.Controls.Add($lblScopeHint)
$ui.lblScopeHint = $lblScopeHint
Update-ScopeHint

$rbProject.Add_CheckedChanged({
  if ($ui.rbProject.Checked) { Switch-EditScope 'project' }
})
$rbGlobal.Add_CheckedChanged({
  if ($ui.rbGlobal.Checked) { Switch-EditScope 'global' }
})

$btnH = [int](28 * $scale)
$topGap = [int](6 * $scale)
$topPadX = [int](16 * $scale)
$topPadY = [int](14 * $scale)

$lblSize = New-HudLabel -Text (Get-HudT 'settings.size') -Fore $th.TextPrimary -Font (New-HudFont 'Segoe UI Semibold' ([float](9 * $scale)) ([System.Drawing.FontStyle]::Bold)) -AutoSize
$top.Controls.Add($lblSize)

$sizeBtns = New-Object System.Collections.ArrayList
foreach ($sz in @('S', 'M', 'L')) {
  $btn = New-FlatBtn $sz ([int](36 * $scale)) $btnH $bgBtn -FixedWidth
  Set-HudMetalButtonPayload $btn $sz
  $btn.Add_Click({
    param($s, $e)
    Apply-SizePreset ([string](Get-HudMetalButtonPayload $s))
    Update-SizeButtonChrome
    Refresh-AfterPreset
  })
  [void]$sizeBtns.Add($btn)
  $top.Controls.Add($btn)
}
$ui.sizeBtns = $sizeBtns
Update-SizeButtonChrome

$lblStyle = New-HudLabel -Text (Get-HudT 'settings.style') -Fore $th.TextPrimary -Font (New-HudFont 'Segoe UI Semibold' ([float](9 * $scale)) ([System.Drawing.FontStyle]::Bold)) -AutoSize
$top.Controls.Add($lblStyle)

$styleBtns = New-Object System.Collections.ArrayList
$styleDefs = @(
  @{ t = (Get-HudT 'settings.style.standard'); id = 'default'; w = 84 },
  @{ t = (Get-HudT 'settings.style.minimal');  id = 'minimal'; w = 72 },
  @{ t = (Get-HudT 'settings.style.hc');       id = 'hc';      w = 44 }
)
if (-not $isPublicFree) {
  $styleDefs += @{ t = (Get-HudT 'settings.style.stripes'); id = 'stripes'; w = 78 }
}
foreach ($st in $styleDefs) {
  $btn = New-FlatBtn $st.t ([int]($st.w * $scale)) $btnH $bgBtn
  Set-HudMetalButtonPayload $btn $st.id
  $btn.Add_Click({
    param($s, $e)
    Apply-StylePreset ([string](Get-HudMetalButtonPayload $s))
    if ($ui.presetMode -or $ui.iconLogoMode) {
      Return-ToStartInspector
    } else {
      Refresh-AfterPreset
    }
  })
  [void]$styleBtns.Add($btn)
  $top.Controls.Add($btn)
}

$btnPreset = New-FlatBtn (Get-HudT 'settings.lookPreset') ([int](148 * $scale)) $btnH ([System.Drawing.Color]::FromArgb(40, 90, 120))
$btnPreset.Visible = (-not $isPublicFree)
$btnPreset.Add_Click({
  if (-not (Test-HudFeature 'hud.lookPresets')) {
    if ($script:hasActivationCli) { Show-HudProHint (Get-HudT 'settings.lookPreset') }
    return
  }
  if ($ui.presetMode) {
    Return-ToStartInspector
  } else {
    Enter-PresetMode
    Apply-SettingsLayout
  }
})
$top.Controls.Add($btnPreset)
$ui.btnPreset = $btnPreset

$btnIconLogo = New-FlatBtn (Get-HudT 'settings.iconLogo') ([int](138 * $scale)) $btnH ([System.Drawing.Color]::FromArgb(40, 90, 120))
$btnIconLogo.Add_Click({
  if ($ui.iconLogoMode) {
    Return-ToStartInspector
  } else {
    Enter-IconLogoMode
    Apply-SettingsLayout
  }
})
$top.Controls.Add($btnIconLogo)
$ui.btnIconLogo = $btnIconLogo

$script:LayoutTopBarChrome = {
  if (-not $ui.topBar) { return }
  $maxRight = [Math]::Max(([int](420 * $scale)), ($ui.topBar.ClientSize.Width - $topPadX))
  $r1Y = $topPadY
  $x = $topPadX
  $lblScope.Location = New-Object System.Drawing.Point($x, ($r1Y + [Math]::Max(0, [int](($rbGlobal.Height - $lblScope.Height) / 2))))
  $x = $lblScope.Right + ([int](8 * $scale))
  if ($rbProject.Visible) {
    $rbProject.Location = New-Object System.Drawing.Point($x, $r1Y)
    $x = $rbProject.Right + ([int](12 * $scale))
  }
  $rbGlobal.Location = New-Object System.Drawing.Point($x, $r1Y)
  $x = $rbGlobal.Right + ([int](14 * $scale))
  $lblScopeHint.Location = New-Object System.Drawing.Point($x, ($r1Y + [Math]::Max(0, [int](($rbGlobal.Height - $lblScopeHint.Height) / 2))))

  $r2Y = [Math]::Max($rbGlobal.Bottom, $lblScope.Bottom) + ([int](12 * $scale))
  $x = $topPadX
  $lblSize.Location = New-Object System.Drawing.Point($x, ($r2Y + [Math]::Max(0, [int](($btnH - $lblSize.Height) / 2))))
  $x = $lblSize.Right + $topGap
  foreach ($btn in $sizeBtns) {
    $btn.Location = New-Object System.Drawing.Point($x, $r2Y)
    $x = $btn.Right + $topGap
  }
  $x += ([int](10 * $scale))
  $lblStyle.Location = New-Object System.Drawing.Point($x, ($r2Y + [Math]::Max(0, [int](($btnH - $lblStyle.Height) / 2))))
  $x = $lblStyle.Right + $topGap
  foreach ($btn in $styleBtns) {
    $btn.Location = New-Object System.Drawing.Point($x, $r2Y)
    $x = $btn.Right + $topGap
  }
  $x += ([int](6 * $scale))
  $needModeW = $(if ($btnPreset.Visible) { $btnPreset.Width + $topGap } else { 0 }) + $btnIconLogo.Width
  if (($x + $needModeW) -gt $maxRight) {
    $r3Y = $r2Y + $btnH + ([int](8 * $scale))
    if ($btnPreset.Visible) {
      $btnPreset.Location = New-Object System.Drawing.Point($topPadX, $r3Y)
      $btnIconLogo.Location = New-Object System.Drawing.Point(($btnPreset.Right + $topGap), $r3Y)
    } else {
      $btnIconLogo.Location = New-Object System.Drawing.Point($topPadX, $r3Y)
    }
    $ui.topBar.Height = $btnIconLogo.Bottom + $topPadY
  } else {
    if ($btnPreset.Visible) {
      $btnPreset.Location = New-Object System.Drawing.Point($x, $r2Y)
      $btnIconLogo.Location = New-Object System.Drawing.Point(($btnPreset.Right + $topGap), $r2Y)
    } else {
      $btnIconLogo.Location = New-Object System.Drawing.Point($x, $r2Y)
    }
    $ui.topBar.Height = ($r2Y + $btnH + $topPadY)
  }
}
& $script:LayoutTopBarChrome
