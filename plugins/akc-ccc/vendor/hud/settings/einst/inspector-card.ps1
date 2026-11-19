# Copyright (c) 2026 ready-4-it
# Einstellungen Right Upper Card: Layer Inspector + Look-Preset grid inside New-HudSectionPanel.
# Dot-sourced from settings/einst/init.ps1 inside Show-SettingsPanel.

$inspHost = New-HudSectionPanel -X ([int](274 * $scale)) -Y ([int](122 * $scale)) -Width ([int](640 * $scale)) -Height ([int](144 * $scale)) -Theme $th
$inspHost.AutoScroll = $false
$ui.pageEinst.Controls.Add($inspHost)
$ui.inspHost = $inspHost

$lblInsp = New-HudLabel -Text 'Inspector' -Fore $th.AccentCyan -Font (New-HudFont 'Segoe UI Semibold' ([float](11 * $scale)) ([System.Drawing.FontStyle]::Bold)) -AutoSize
$lblInsp.Location = New-Object System.Drawing.Point(([int](16 * $scale)), ([int](14 * $scale)))
$inspHost.Controls.Add($lblInsp)
$ui.lblInsp = $lblInsp

$lblInspPurpose = New-HudLabel -Text '' -Fore $th.TextMuted -Font (New-HudFont 'Segoe UI' ([float](8.5 * $scale)))
$lblInspPurpose.Tag = 'lblInspPurpose'
$lblInspPurpose.AutoSize = $false
$lblInspPurpose.Height = [int](32 * $scale)
$inspHost.Controls.Add($lblInspPurpose)
[void]$ui.inspCtrls.Add($lblInspPurpose)
$ui.lblInspPurpose = $lblInspPurpose

# Look-Preset 2-column grid (Pro only — skip building ~150 controls in Public Free for instant dialog open)
$imageCats = @()
if ($script:hasActivationCli) {
$themePanel = New-Object System.Windows.Forms.Panel
$themePanel.Location = New-Object System.Drawing.Point(([int](14 * $scale)), ([int](42 * $scale)))
$themePanel.Size = New-Object System.Drawing.Size(([int](612 * $scale)), ([int](360 * $scale)))
$themePanel.Visible = $false
$themePanel.AutoScroll = $true
$themePanel.BackColor = [System.Drawing.Color]::FromArgb(22, 26, 34)
Enable-HudDoubleBuffer -Control $themePanel
$inspHost.Controls.Add($themePanel)
$ui.themePanel = $themePanel

$lblThemeHint = New-HudLabel -Text (Get-HudT 'settings.theme.hint') -Fore $th.ProGold -Font (New-HudFont 'Segoe UI' ([float](8.75 * $scale)))
$lblThemeHint.AutoSize = $false
$lblThemeHint.Dock = [System.Windows.Forms.DockStyle]::Top
$lblThemeHint.Height = [int](34 * $scale)
$lblThemeHint.Padding = New-Object System.Windows.Forms.Padding(([int](6 * $scale)), ([int](2 * $scale)), ([int](6 * $scale)), ([int](4 * $scale)))
$themePanel.Controls.Add($lblThemeHint)

$lookCats = @($ui.themeCategories | Where-Object { [string]$_.kind -ne 'image' })
$imageCats = @($ui.themeCategories | Where-Object { [string]$_.kind -eq 'image' })
$formCats = @($lookCats | Where-Object { [string]$_.kind -eq 'form' -or [string]$_.id -eq '3d' })
$colorCats = @($lookCats | Where-Object { [string]$_.kind -ne 'form' -and [string]$_.id -ne '3d' })
$orderedCats = @($formCats) + @($colorCats)
$colorRowCount = [Math]::Max(1, [int][Math]::Ceiling($colorCats.Count / 2.0))
$formRowH = [int](148 * $scale)
$colorRowH = [int](160 * $scale)

$themeGrid = New-Object System.Windows.Forms.TableLayoutPanel
$themeGrid.Dock = [System.Windows.Forms.DockStyle]::Top
$themeGrid.ColumnCount = 2
$themeGrid.RowCount = 1 + $colorRowCount
$themeGrid.Height = $formRowH + ($colorRowCount * $colorRowH)
$themeGrid.BackColor = [System.Drawing.Color]::FromArgb(22, 26, 34)
[void]$themeGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50.0)))
[void]$themeGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50.0)))
[void]$themeGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, ([single]$formRowH))))
for ($ri = 0; $ri -lt $colorRowCount; $ri++) {
  [void]$themeGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, ([single]$colorRowH))))
}
$themePanel.Controls.Add($themeGrid)
$themeGrid.BringToFront()
$ui.themeGrid = $themeGrid
$themePanel.Add_Resize({
  param($s, $e)
  if (-not $ui.themeGrid) { return }
  $sbW = [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth
  $ui.themeGrid.Width = [Math]::Max(40, ($s.ClientSize.Width - [int](4 * $scale)))
  if ($lblThemeHint) {
    $lblThemeHint.Height = [Math]::Max(([int](26 * $scale)), ((Measure-HudWrap -Text $lblThemeHint.Text -Font $lblThemeHint.Font -MaxWidth ([Math]::Max(80, ($s.ClientSize.Width - $sbW - [int](12 * $scale))))) + ([int](8 * $scale))))
  }
})

$catIndex = 0
foreach ($cat in $orderedCats) {
  $isForm = ([string]$cat.kind -eq 'form' -or [string]$cat.id -eq '3d')
  if ($isForm) {
    $col = 0
    $row = 0
  } else {
    $col = $catIndex % 2
    $row = 1 + [Math]::Floor($catIndex / 2)
    $catIndex++
  }
  $catPanel = New-Object System.Windows.Forms.Panel
  $catPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
  $catPanel.AutoScroll = $isForm
  $catPanel.Padding = New-Object System.Windows.Forms.Padding(([int](8 * $scale)))
  $catPanel.Margin = New-Object System.Windows.Forms.Padding(([int](4 * $scale)))
  Add-HudSubPanelHairline $catPanel $th

  $hl = New-HudLabel -Text ([string]$cat.label) -Fore $th.AccentCyan -Font (New-HudFont 'Segoe UI Semibold' ([float](10 * $scale)) ([System.Drawing.FontStyle]::Bold)) -AutoSize
  $hl.Location = New-Object System.Drawing.Point(([int](8 * $scale)), ([int](6 * $scale)))
  $catPanel.Controls.Add($hl)

  $ty = [int](30 * $scale)
  foreach ($opt in @($cat.options)) {
    $optRow = New-Object System.Windows.Forms.Panel
    $optRow.Height = [int](($(if ($isForm) { 28 } else { 26 })) * $scale)
    $optRow.Width = [int](280 * $scale)
    $optRow.Location = New-Object System.Drawing.Point(([int](4 * $scale)), $ty)
    $optRow.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $optRow.BackColor = [System.Drawing.Color]::Transparent

    $rb = New-Object System.Windows.Forms.RadioButton
    $rb.Text = [string]$opt.label
    $rb.Tag = [string]$opt.id
    $rb.AutoSize = $true
    $rb.Location = New-Object System.Drawing.Point(([int](4 * $scale)), ([int](4 * $scale)))
    $rb.ForeColor = $th.TextPrimary
    $rb.Font = New-HudFont 'Segoe UI' ([float](9.5 * $scale))
    $rb.Add_CheckedChanged({
      param($s, $e)
      if (-not $s.Checked) { return }
      if ($ui.syncing) { return }
      Select-ThemeOption ([string]$s.Tag)
    })
    $optRow.Controls.Add($rb)

    $optFx = ''
    $chip = $null
    if (Get-Command Get-HudLookFxFromSug -ErrorAction SilentlyContinue) {
      $optFx = Get-HudLookFxFromSug $opt
    } elseif (Get-Command Get-HudLookFxName -ErrorAction SilentlyContinue) {
      $optFx = Get-HudLookFxName ([string]$opt.lookFx)
      if (-not $optFx) { $optFx = Get-HudLookFxName ([string]$opt.id) }
    }
    $sx = [int](96 * $scale)
    if ($optFx -and ('HudLookFx' -as [type])) {
      $chipW = [int](72 * $scale)
      $chipH = [int](20 * $scale)
      $fillC = Parse-HexColor ([string]$opt.fillColor)
      if ($null -eq $fillC) { $fillC = [System.Drawing.Color]::FromArgb(22, 28, 38) }
      $accC = Parse-HexColor ([string]$opt.markerColor)
      if ($null -eq $accC) { $accC = Parse-HexColor ([string]$opt.borderColor) }
      if ($null -eq $accC) { $accC = [System.Drawing.Color]::FromArgb(90, 209, 232) }
      $bordC = Parse-HexColor ([string]$opt.borderColor)
      if ($null -eq $bordC) { $bordC = $accC }
      try {
        $textC = Parse-HexColor ([string]$opt.textColor)
        if ($null -eq $textC) { $textC = Parse-HexColor ([string]$script:prefs.textColor) }
        if ($null -eq $textC) { $textC = [System.Drawing.Color]::White }
        $chipBmp = [HudLookFx]::Chip($chipW, $chipH, $optFx, $fillC, $accC, $bordC, $textC)
        $chip = New-Object System.Windows.Forms.PictureBox
        $chip.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage
        $chip.Size = New-Object System.Drawing.Size($chipW, $chipH)
        $chip.Location = New-Object System.Drawing.Point($sx, ([int](4 * $scale)))
        $chip.Image = $chipBmp
        $chip.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $optRow.Controls.Add($chip)
        [void]$ui.themeArtImages.Add($chipBmp)
      } catch { }
    } else {
      $swatches = @()
      if ($opt.swatches) { $swatches = @($opt.swatches) }
      foreach ($hex in $swatches) {
        $swColor = Parse-HexColor ([string]$hex)
        if ($null -eq $swColor) { continue }
        $sw = New-Object System.Windows.Forms.Panel
        $sw.Size = New-Object System.Drawing.Size(([int](14 * $scale)), ([int](14 * $scale)))
        $sw.Location = New-Object System.Drawing.Point($sx, ([int](5 * $scale)))
        $sw.BackColor = $swColor
        $sw.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $optRow.Controls.Add($sw)
        $sx += [int](16 * $scale)
      }
    }
    $catPanel.Controls.Add($optRow)
    [void]$ui.themeRadios.Add($rb)
    if ($isForm) {
      if ($null -eq $chip) {
        $chip = New-Object System.Windows.Forms.PictureBox
        $chip.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::StretchImage
        $chip.Size = New-Object System.Drawing.Size(([int](72 * $scale)), ([int](20 * $scale)))
        $chip.Location = New-Object System.Drawing.Point($sx, ([int](4 * $scale)))
        $chip.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $optRow.Controls.Add($chip)
      }
      [void]$ui.formRadios.Add($rb)
      [void]$ui.formChips.Add(@{ box = $chip; fx = [string]$optFx })
    } else {
      [void]$ui.colorRadios.Add($rb)
    }
    $ty += [int](($(if ($isForm) { 28 } else { 26 })) * $scale)
  }
  $themeGrid.Controls.Add($catPanel, $col, $row)
  if ($isForm) { $themeGrid.SetColumnSpan($catPanel, 2) }
}
Update-FormChips
} # end if ($script:hasActivationCli)

# --- Layer Inspector controls (dark inputs, zero white fields) ---
function Add-InspLabel([string]$tag, [string]$text, [int]$x, [int]$y) {
  $l = New-HudLabel -Text $text -Fore $th.TextPrimary -Font (New-HudFont 'Segoe UI Semibold' ([float](9 * $scale))) -AutoSize
  $l.Tag = $tag
  $l.Location = New-Object System.Drawing.Point($x, $y)
  $inspHost.Controls.Add($l); [void]$ui.inspCtrls.Add($l)
  return $l
}
function Add-InspNum([string]$tag, [decimal]$min, [decimal]$max, [int]$x, [int]$y, [int]$w) {
  $n = New-HudNumericUpDown -Minimum $min -Maximum $max -Increment 1 -Width ([Math]::Max(76, $w)) -Height ([int](26 * $scale)) -Scale $scale -Theme $th
  $n.Tag = $tag
  $n.Location = New-Object System.Drawing.Point($x, $y)
  $inspHost.Controls.Add($n); [void]$ui.inspCtrls.Add($n)
  return $n
}
function Add-InspText([string]$tag, [int]$x, [int]$y, [int]$w) {
  $t = New-DarkText $w
  $t.Tag = $tag; $t.Location = New-Object System.Drawing.Point($x, $y)
  $inspHost.Controls.Add($t); [void]$ui.inspCtrls.Add($t)
  return $t
}
function Add-InspBtn([string]$tag, [string]$text, [int]$x, [int]$y) {
  $b = New-FlatBtn $text ([int](28 * $scale)) ([int](24 * $scale)) $bgBtn
  Set-HudMetalButtonPayload $b $tag
  $b.Location = New-Object System.Drawing.Point($x, $y)
  $inspHost.Controls.Add($b); [void]$ui.inspCtrls.Add($b)
  return $b
}

$ix = [int](16 * $scale); $iy = [int](42 * $scale); $iw = [int](100 * $scale)
$ctrlX = [int](176 * $scale); $txtW = [int](200 * $scale); $btnX = [int](386 * $scale)
$row2 = [int]($iy + 34 * $scale)
$row3 = [int]($iy + 68 * $scale)
$row4 = [int]($iy + 102 * $scale)

[void](Add-InspLabel 'lMargin' (Get-HudT 'settings.margin') $ix $iy)
$ui.numMargin = Add-InspNum 'numMargin' 0 24 $ix ([int]($iy + 24 * $scale)) $iw
[void](Add-InspLabel 'lPad' (Get-HudT 'settings.padding') $ix $iy)
$ui.numPad = Add-InspNum 'numPad' 0 24 $ix ([int]($iy + 24 * $scale)) $iw

[void](Add-InspLabel 'lBorderC' (Get-HudT 'settings.borderColor') $ix ($iy + [int](3 * $scale)))
$ui.txtBorderC = Add-InspText 'txtBorderC' $ctrlX $iy $txtW
$btnBorderC = Add-InspBtn 'btnBorderC' '…' $btnX $iy
[void](Add-InspLabel 'lBorderW' (Get-HudT 'settings.borderWidth') $ix ($row2 + [int](3 * $scale)))
$ui.numBorderW = Add-InspNum 'numBorderW' 1 8 $ctrlX $row2 $iw

[void](Add-InspLabel 'lFont' (Get-HudT 'settings.font') $ix ($iy + [int](3 * $scale)))
$ui.cmbFont = New-DarkCombo $txtW @('Segoe UI', 'Cascadia Mono', 'Consolas', 'Arial', 'Tahoma', 'Segoe UI Emoji')
$ui.cmbFont.Tag = 'cmbFont'
$ui.cmbFont.Location = New-Object System.Drawing.Point($ctrlX, $iy)
$inspHost.Controls.Add($ui.cmbFont); [void]$ui.inspCtrls.Add($ui.cmbFont)
[void](Add-InspLabel 'lFontSz' (Get-HudT 'settings.fontSize') $ix ($row2 + [int](3 * $scale)))
$ui.numFontSz = Add-InspNum 'numFontSz' 8 28 $ctrlX $row2 $iw
[void](Add-InspLabel 'lFill' (Get-HudT 'settings.fill') $ix ($row3 + [int](3 * $scale)))
$ui.txtFill = Add-InspText 'txtFill' $ctrlX $row3 $txtW
$btnFill = Add-InspBtn 'btnFill' '…' $btnX $row3
[void](Add-InspLabel 'lTextC' (Get-HudT 'settings.textColor') $ix ($row4 + [int](3 * $scale)))
$ui.txtTextC = Add-InspText 'txtTextC' $ctrlX $row4 $txtW
$btnTextC = Add-InspBtn 'btnTextC' '…' $btnX $row4
