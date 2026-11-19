# Copyright (c) 2026 ready-4-it
# Einstellungen Right Lower Card: Icon / Pattern / Logo / Orb / Pro / Autostart inside New-HudSectionPanel.
# Dot-sourced from settings/einst/init.ps1 inside Show-SettingsPanel.

$iconCard = New-HudSectionPanel -X ([int](274 * $scale)) -Y ([int](278 * $scale)) -Width ([int](640 * $scale)) -Height ([int](248 * $scale)) -Theme $th
$ui.pageEinst.Controls.Add($iconCard)
$ui.iconCard = $iconCard

# Scrollable interior inset inside $iconCard so card hairline + cyan corner brackets stay untouched
$iconHost = New-Object System.Windows.Forms.Panel
$iconHost.Location = New-Object System.Drawing.Point(3, 3)
$iconHost.Size = New-Object System.Drawing.Size(([int](634 * $scale)), ([int](242 * $scale)))
$iconHost.AutoScroll = $true
$iconHost.BackColor = [System.Drawing.Color]::FromArgb(22, 26, 34)
Enable-HudDoubleBuffer -Control $iconHost
$iconCard.Controls.Add($iconHost)
$ui.iconHost = $iconHost

# --- Orbs sub-card inside Icon block (Pro only — skip building in Public Free) ---
$ui.orbHost = $null
$ui.orbPanel = $null
if ($script:hasActivationCli) {
$bgHost = New-Object System.Windows.Forms.Panel
$bgHost.Height = [int](172 * $scale)
$bgHost.Padding = New-Object System.Windows.Forms.Padding(([int](8 * $scale)))
Add-HudSubPanelHairline $bgHost $th
$iconHost.Controls.Add($bgHost)
$ui.orbHost = $bgHost
$ui.orbPanel = $null

$hlBg = New-HudLabel -Text (Get-HudT 'settings.theme.bgTitle') -Fore $th.ProGold -Font (New-HudFont 'Segoe UI Semibold' ([float](10 * $scale)) ([System.Drawing.FontStyle]::Bold)) -AutoSize
$hlBg.Location = New-Object System.Drawing.Point(([int](8 * $scale)), ([int](6 * $scale)))
$bgHost.Controls.Add($hlBg)

$bgHint = New-HudLabel -Text (Get-HudT 'settings.theme.bgHint') -Fore $th.TextMuted -Font (New-HudFont 'Segoe UI' ([float](8.75 * $scale))) -AutoSize
$bgHint.Location = New-Object System.Drawing.Point(([int](8 * $scale)), ([int](28 * $scale)))
$bgHost.Controls.Add($bgHint)

$chkOverwriteLogo = New-Object System.Windows.Forms.CheckBox
$chkOverwriteLogo.Text = Get-HudT 'settings.logo.overwrite'
$chkOverwriteLogo.AutoSize = $true
$chkOverwriteLogo.BackColor = [System.Drawing.Color]::Transparent
$chkOverwriteLogo.ForeColor = $th.TextPrimary
$chkOverwriteLogo.Font = New-HudFont 'Segoe UI' ([float](9 * $scale))
$chkOverwriteLogo.Location = New-Object System.Drawing.Point(([int](8 * $scale)), ([int](50 * $scale)))
$ovPref = $false
try { $ovPref = [bool]$script:prefs.overwriteCustomLogo } catch { $ovPref = $false }
$chkOverwriteLogo.Checked = $ovPref
$chkOverwriteLogo.Add_CheckedChanged({
  if ($ui.syncing) { return }
  $script:prefs.overwriteCustomLogo = [bool]$ui.chkOverwriteLogo.Checked
})
$bgHost.Controls.Add($chkOverwriteLogo)
$ui.chkOverwriteLogo = $chkOverwriteLogo

$thumbFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$thumbFlow.Location = New-Object System.Drawing.Point(([int](8 * $scale)), ([int](76 * $scale)))
$thumbFlow.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$thumbFlow.Size = New-Object System.Drawing.Size(([int](600 * $scale)), ([int](88 * $scale)))
$thumbFlow.WrapContents = $false
$thumbFlow.AutoScroll = $true
$thumbFlow.BackColor = [System.Drawing.Color]::FromArgb(18, 22, 29)
$bgHost.Controls.Add($thumbFlow)
$bgHost.Add_Resize({
  param($s, $e)
  if ($thumbFlow) {
    $thumbFlow.Width = [Math]::Max(60, ($s.ClientSize.Width - ([int](16 * $scale))))
  }
})

$bgOpts = @()
foreach ($ic in $imageCats) { foreach ($o in @($ic.options)) { $bgOpts += $o } }
foreach ($opt in $bgOpts) {
  $card = New-Object System.Windows.Forms.Panel
  $card.Size = New-Object System.Drawing.Size(([int](92 * $scale)), ([int](76 * $scale)))
  $card.Margin = New-Object System.Windows.Forms.Padding(([int](4 * $scale)))
  Add-HudSubPanelHairline $card $th
  $card.Tag = [string]$opt.id

  $pb = New-Object System.Windows.Forms.PictureBox
  $pb.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
  $pb.Size = New-Object System.Drawing.Size(([int](78 * $scale)), ([int](48 * $scale)))
  $pb.Location = New-Object System.Drawing.Point(([int](7 * $scale)), ([int](4 * $scale)))
  $pb.BackColor = [System.Drawing.Color]::FromArgb(14, 17, 24)
  $pb.Tag = [string]$opt.id
  if ($opt.imagePath -and (Test-HudPath ([string]$opt.imagePath))) {
    try {
      $img = if (Get-Command Read-HudImageBitmap -ErrorAction SilentlyContinue) {
        Read-HudImageBitmap -Path ([string]$opt.imagePath)
      } else {
        $bytes = [System.IO.File]::ReadAllBytes([string]$opt.imagePath)
        $ms = New-Object System.IO.MemoryStream(,$bytes)
        try { [System.Drawing.Image]::FromStream($ms) } finally { }
      }
      if ($null -ne $img) {
        $pb.Image = $img
        [void]$ui.themeArtImages.Add($img)
      }
    } catch { }
  }

  $rb = New-Object System.Windows.Forms.RadioButton
  $rb.UseMnemonic = $false
  $rb.Text = [string]$opt.label
  $rb.Tag = [string]$opt.id
  $rb.AutoSize = $true
  $rb.Location = New-Object System.Drawing.Point(([int](4 * $scale)), ([int](54 * $scale)))
  $rb.ForeColor = $th.TextPrimary
  $rb.Font = New-HudFont 'Segoe UI' ([float](8.5 * $scale))
  $rb.Add_CheckedChanged({
    param($s, $e)
    if (-not $s.Checked) { return }
    if ($ui.syncing) { return }
    Select-OrbOption ([string]$s.Tag)
  })
  $clickBg = {
    param($s, $e)
    if ($ui.syncing) { return }
    $tid = [string]$s.Tag
    if (-not $tid) { return }
    Select-OrbOption $tid
  }
  $pb.Add_Click($clickBg)
  $card.Add_Click($clickBg)

  $card.Controls.Add($pb)
  $card.Controls.Add($rb)
  $thumbFlow.Controls.Add($card)
  [void]$ui.orbRadios.Add($rb)
}
} # end if ($script:hasActivationCli)

# --- Icon / Pattern / Custom Logo controls ---
$lblIcon = New-HudLabel -Text (Get-HudT 'settings.iconTitle') -Fore $th.AccentCyan -Font (New-HudFont 'Segoe UI Semibold' ([float](11 * $scale)) ([System.Drawing.FontStyle]::Bold)) -AutoSize
$iconHost.Controls.Add($lblIcon)

$lm = New-HudLabel -Text (Get-HudT 'settings.mode') -Fore $th.TextPrimary -Font (New-HudFont 'Segoe UI Semibold' ([float](9 * $scale))) -AutoSize
$iconHost.Controls.Add($lm)
$ui.cmbMode = New-DarkCombo ([int](120 * $scale)) @('emoji', 'pattern', 'image')
$iconHost.Controls.Add($ui.cmbMode)

$lc = New-HudLabel -Text (Get-HudT 'settings.iconColor') -Fore $th.TextPrimary -Font (New-HudFont 'Segoe UI Semibold' ([float](9 * $scale))) -AutoSize
$iconHost.Controls.Add($lc)
$ui.txtMarkC = New-DarkText ([int](110 * $scale))
$iconHost.Controls.Add($ui.txtMarkC)
$btnMarkC = New-FlatBtn '…' ([int](28 * $scale)) ([int](24 * $scale)) $bgBtn
$iconHost.Controls.Add($btnMarkC)

$emojiFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$emojiFlow.WrapContents = $true
$emojiFlow.AutoScroll = $false
$emojiFlow.BackColor = [System.Drawing.Color]::FromArgb(22, 26, 34)
$emojiFlow.Padding = New-Object System.Windows.Forms.Padding(0)
$emojiFlow.Margin = New-Object System.Windows.Forms.Padding(0)
$iconHost.Controls.Add($emojiFlow)
$isPublicFree = (-not $script:hasActivationCli)
$allowFullEmoji = Test-HudFeature 'hud.marker.emoji.full'
$emojiBaseList = if ($allowFullEmoji) {
  @('🔵', '🟢', '🟡', '🔴', '🟣', '⚪', '⬛', '🚀', '🎯', '⚡', '🔥', '💎', '🧭', '📌', '✅', '⚠️')
} else {
  @('🔵', '🟢', '🟡', '🔴', '🟣', '⚪', '🚀', '🎯', '⚡', '🔥')
}
foreach ($em in $emojiBaseList) {
  $eb = New-HudEmojiButton -Emoji $em -Width ([int](34 * $scale)) -Height ([int](30 * $scale)) -Theme $th
  $eb.Tag = $em
  $eb.Margin = New-Object System.Windows.Forms.Padding(([int](2 * $scale)))
  $eb.Add_Click({
    param($s, $e)
    $script:dlgMarkerEmoji = [string]$s.Tag
    $script:prefs.markerEmoji = $script:dlgMarkerEmoji
    $script:prefs.markerMode = 'emoji'
    Clear-OrbPick
    $ui.syncing = $true
    try { $ui.cmbMode.SelectedItem = 'emoji' } finally { $ui.syncing = $false }
    Sync-FromInspector
  })
  $emojiFlow.Controls.Add($eb)
}
if ($allowFullEmoji) {
  foreach ($opt in $ui.themeOptions) {
    if ([string]$opt.kind -eq 'image') { continue }
    $em = [string]$opt.emoji
    if ([string]::IsNullOrWhiteSpace($em)) { continue }
    $already = $false
    foreach ($c in $emojiFlow.Controls) {
      if ([string]$c.Tag -eq $em) { $already = $true; break }
    }
    if ($already) { continue }
    $eb = New-HudEmojiButton -Emoji $em -Width ([int](34 * $scale)) -Height ([int](30 * $scale)) -Theme $th
    $eb.Tag = $em
    $eb.Margin = New-Object System.Windows.Forms.Padding(([int](2 * $scale)))
    $eb.Add_Click({
      param($s, $e)
      $script:dlgMarkerEmoji = [string]$s.Tag
      $script:prefs.markerEmoji = $script:dlgMarkerEmoji
      $script:prefs.markerMode = 'emoji'
      Clear-OrbPick
      $ui.syncing = $true
      try { $ui.cmbMode.SelectedItem = 'emoji' } finally { $ui.syncing = $false }
      Sync-FromInspector
    })
    $emojiFlow.Controls.Add($eb)
  }
}

$lp = New-HudLabel -Text (Get-HudT 'settings.pattern') -Fore $th.TextPrimary -Font (New-HudFont 'Segoe UI Semibold' ([float](9 * $scale))) -AutoSize
$iconHost.Controls.Add($lp)
$ui.cmbPat = New-DarkCombo ([int](140 * $scale)) @('stripes', 'dots', 'solid', 'chevron', 'grid')
$iconHost.Controls.Add($ui.cmbPat)

$ll = New-HudLabel -Text (Get-HudT 'settings.logo') -Fore $th.TextPrimary -Font (New-HudFont 'Segoe UI Semibold' ([float](9 * $scale))) -AutoSize
$iconHost.Controls.Add($ll)
$ui.txtLogo = New-DarkText ([int](260 * $scale))
$iconHost.Controls.Add($ui.txtLogo)
$btnLogo = New-FlatBtn (Get-HudT 'settings.logo.browse') ([int](114 * $scale)) ([int](26 * $scale)) $bgBtn
$iconHost.Controls.Add($btnLogo)
$ui.btnLogo = $btnLogo

$ui.lblLogoRecent = New-HudLabel -Text (Get-HudT 'settings.logo.recent') -Fore $th.TextPrimary -Font (New-HudFont 'Segoe UI Semibold' ([float](9 * $scale))) -AutoSize
$iconHost.Controls.Add($ui.lblLogoRecent)
$ui.cmbLogoRecent = New-DarkCombo ([int](280 * $scale)) @((Get-HudT 'settings.logo.recent.pick'))
$iconHost.Controls.Add($ui.cmbLogoRecent)

$ui.lblLogoHint = New-HudLabel -Text (Get-HudT 'settings.logo.hint.empty') -Fore $th.TextMuted -Font (New-HudFont 'Segoe UI' ([float](8.5 * $scale))) -AutoSize
$iconHost.Controls.Add($ui.lblLogoHint)

$ui.lblProIcon = New-HudLabel -Text '' -Fore $th.ProGold -Font (New-HudFont 'Segoe UI Semibold' ([float](8.75 * $scale))) -AutoSize
$iconHost.Controls.Add($ui.lblProIcon)

$proExtras = New-Object System.Windows.Forms.Panel
$proExtras.Height = [int](68 * $scale)
$proExtras.BackColor = [System.Drawing.Color]::FromArgb(22, 26, 34)
$iconHost.Controls.Add($proExtras)

# Created here so winforms-storage-tabs.ps1 can move them into the Backup card cleanly
$ui.btnExportPrefs = New-FlatBtn (Get-HudT 'settings.prefs.export') ([int](150 * $scale)) ([int](30 * $scale)) $bgBtn
$proExtras.Controls.Add($ui.btnExportPrefs)
$ui.btnImportPrefs = New-FlatBtn (Get-HudT 'settings.prefs.import') ([int](150 * $scale)) ([int](30 * $scale)) $bgBtn
$proExtras.Controls.Add($ui.btnImportPrefs)
$ui.btnSaveProfile = New-FlatBtn (Get-HudT 'settings.profile.save') ([int](140 * $scale)) ([int](30 * $scale)) $bgBtn
$proExtras.Controls.Add($ui.btnSaveProfile)
$ui.btnLoadProfile = New-FlatBtn (Get-HudT 'settings.profile.load') ([int](120 * $scale)) ([int](30 * $scale)) $bgBtn
$proExtras.Controls.Add($ui.btnLoadProfile)

$ui.chkAutostart = New-Object System.Windows.Forms.CheckBox
$ui.chkAutostart.Text = Get-HudT 'settings.autostart'
$ui.chkAutostart.AutoSize = $true
$ui.chkAutostart.BackColor = [System.Drawing.Color]::Transparent
$ui.chkAutostart.ForeColor = $th.TextPrimary
$ui.chkAutostart.Font = New-HudFont 'Segoe UI Semibold' ([float](9 * $scale))
$ui.chkAutostart.Checked = [bool]$script:prefs.autostart
$proExtras.Controls.Add($ui.chkAutostart)

$ui.lblPrefsHint = New-HudLabel -Text (Get-HudT 'settings.prefs.vsProfile') -Fore $th.TextMuted -Font (New-HudFont 'Segoe UI' ([float](8.25 * $scale))) -AutoSize
$proExtras.Controls.Add($ui.lblPrefsHint)

$script:LayoutIconBlock = {
  if (-not $ui.iconHost) { return }
  $pad = [int](14 * $scale)
  $gap = [int](8 * $scale)
  $sbW = [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth
  $cw = [Math]::Max(([int](420 * $scale)), ($ui.iconHost.Width - (2 * $pad) - $sbW))
  $y = [int](12 * $scale)
  $x = $pad

  $lblIcon.Location = New-Object System.Drawing.Point($x, $y)
  $y = $lblIcon.Bottom + $gap

  if ($isPublicFree) {
    foreach ($hideCtrl in @($lm, $ui.cmbMode, $lp, $ui.cmbPat, $ll, $ui.txtLogo, $btnLogo, $ui.lblLogoRecent, $ui.cmbLogoRecent, $ui.lblLogoHint, $ui.orbHost, $proExtras)) {
      if ($hideCtrl) { $hideCtrl.Visible = $false }
    }
    $lc.Location = New-Object System.Drawing.Point($x, ($y + 4))
    $ui.txtMarkC.Location = New-Object System.Drawing.Point(($lc.Right + $gap), $y)
    $btnMarkC.Location = New-Object System.Drawing.Point(($ui.txtMarkC.Right + $gap), $y)
    $y = $btnMarkC.Bottom + $gap

    $emojiFlow.Location = New-Object System.Drawing.Point($x, $y)
    $emojiFlow.Width = $cw
    $emojiFlow.Height = [int](72 * $scale)
    $y = $emojiFlow.Bottom + $gap

    $ui.lblProIcon.MaximumSize = New-Object System.Drawing.Size($cw, 0)
    $ui.lblProIcon.Location = New-Object System.Drawing.Point($x, $y)
    $needH = $ui.lblProIcon.Bottom + $pad
    $avail = $ui.iconHost.ClientSize.Height
    if ($avail -gt 40 -and $needH -le $avail) {
      $ui.iconHost.AutoScroll = $false
      $ui.iconHost.AutoScrollMinSize = New-Object System.Drawing.Size(0, 0)
    } else {
      $ui.iconHost.AutoScroll = $true
      $ui.iconHost.AutoScrollMinSize = New-Object System.Drawing.Size(0, $needH)
    }
    return
  }

  $lm.Location = New-Object System.Drawing.Point($x, ($y + 4))
  $ui.cmbMode.Location = New-Object System.Drawing.Point(($lm.Right + $gap), $y)
  $lc.Location = New-Object System.Drawing.Point(($ui.cmbMode.Right + ([int](16 * $scale))), ($y + 4))
  $ui.txtMarkC.Location = New-Object System.Drawing.Point(($lc.Right + $gap), $y)
  $btnMarkC.Location = New-Object System.Drawing.Point(($ui.txtMarkC.Right + $gap), $y)
  $y = [Math]::Max($ui.cmbMode.Bottom, $btnMarkC.Bottom) + $gap

  $emojiFlow.Location = New-Object System.Drawing.Point($x, $y)
  $emojiFlow.Width = $cw
  $emojiFlow.Height = [int](72 * $scale)
  $y = $emojiFlow.Bottom + $gap

  $lp.Location = New-Object System.Drawing.Point($x, ($y + 4))
  $ui.cmbPat.Location = New-Object System.Drawing.Point(($lp.Right + $gap), $y)
  $y = [Math]::Max($lp.Bottom, $ui.cmbPat.Bottom) + $gap

  $ll.Location = New-Object System.Drawing.Point($x, ($y + 4))
  $logoW = [Math]::Max(([int](180 * $scale)), ($cw - $ll.Width - (2 * $gap) - $ui.btnLogo.Width))
  $ui.txtLogo.Width = $logoW
  $ui.txtLogo.Location = New-Object System.Drawing.Point(($ll.Right + $gap), $y)
  $btnLogo.Location = New-Object System.Drawing.Point(($ui.txtLogo.Right + $gap), $y)
  $y = [Math]::Max($ui.txtLogo.Bottom, $btnLogo.Bottom) + ([int](6 * $scale))

  if ($ui.lblLogoRecent -and $ui.cmbLogoRecent) {
    $ui.lblLogoRecent.Location = New-Object System.Drawing.Point($x, ($y + 4))
    $ui.cmbLogoRecent.Width = [Math]::Max(([int](180 * $scale)), ($cw - $ui.lblLogoRecent.Width - $gap))
    $ui.cmbLogoRecent.Location = New-Object System.Drawing.Point(($ui.lblLogoRecent.Right + $gap), $y)
    $y = [Math]::Max($ui.lblLogoRecent.Bottom, $ui.cmbLogoRecent.Bottom) + ([int](6 * $scale))
  }
  if ($ui.lblLogoHint) {
    $ui.lblLogoHint.MaximumSize = New-Object System.Drawing.Size($cw, 0)
    $ui.lblLogoHint.Location = New-Object System.Drawing.Point($x, $y)
    $y = $ui.lblLogoHint.Bottom + $gap
  }

  if ($ui.orbHost) {
    $ui.orbHost.Location = New-Object System.Drawing.Point($x, $y)
    $ui.orbHost.Width = $cw
    $ui.orbHost.Height = [int](172 * $scale)
    $y = $ui.orbHost.Bottom + $gap
  }

  $ui.lblProIcon.MaximumSize = New-Object System.Drawing.Size($cw, 0)
  $ui.lblProIcon.Location = New-Object System.Drawing.Point($x, $y)
  $y = $ui.lblProIcon.Bottom + $gap

  $proExtras.Location = New-Object System.Drawing.Point($x, $y)
  $proExtras.Width = $cw
  $bgap = [int](6 * $scale)
  $ui.chkAutostart.MaximumSize = New-Object System.Drawing.Size([Math]::Max(40, $cw), 0)
  $ui.chkAutostart.Location = New-Object System.Drawing.Point(0, 0)
  $hintY = $ui.chkAutostart.Bottom + $bgap
  if ($ui.lblPrefsHint) {
    $ui.lblPrefsHint.MaximumSize = New-Object System.Drawing.Size([Math]::Max(40, $cw), 0)
    $ui.lblPrefsHint.Location = New-Object System.Drawing.Point(0, $hintY)
    $hintY = $ui.lblPrefsHint.Bottom
  }
  $proExtras.Height = $hintY + $bgap

  $needH = $proExtras.Bottom + $pad
  $avail = $ui.iconHost.ClientSize.Height
  if ($avail -gt 40 -and $needH -le $avail) {
    $ui.iconHost.AutoScroll = $false
    $ui.iconHost.AutoScrollMinSize = New-Object System.Drawing.Size(0, 0)
  } else {
    $ui.iconHost.AutoScroll = $true
    $ui.iconHost.AutoScrollMinSize = New-Object System.Drawing.Size(0, $needH)
  }
}
$iconHost.Add_Resize({ if ($script:LayoutIconBlock) { & $script:LayoutIconBlock } })
& $script:LayoutIconBlock
