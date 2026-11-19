# Copyright (c) 2026 ready-4-it
# Einstellungen Left Card: Box-Model & Mini-Preview inside one New-HudSectionPanel.
# Dot-sourced from settings/einst/init.ps1 inside Show-SettingsPanel.

# Load universal theme categories (Pastell / Metall / 3D / Neon + Hintergrund — Pro only)
if ($script:hasActivationCli) {
  $catalog = Load-HudPresetCatalog
  $artDir = Join-Path $PSScriptRoot '..\..\preset-art'
  if (-not (Test-HudPath $artDir) -and $script:HudScriptRoot) {
    $artDir = Join-Path $script:HudScriptRoot 'preset-art'
  }
  if ($null -ne $catalog -and $catalog.categories) {
    foreach ($cat in @($catalog.categories)) {
      $kind = [string]$cat.kind
      if ([string]::IsNullOrWhiteSpace($kind)) { $kind = 'look' }
      $catObj = @{
        id = [string]$cat.id
        label = [string]$cat.label
        kind = $kind
        options = (New-Object System.Collections.ArrayList)
      }
      foreach ($o in @($cat.options)) {
        $imgRel = [string]$o.image
        $imgAbs = ''
        if (-not [string]::IsNullOrWhiteSpace($imgRel)) {
          $cand = Join-Path $artDir $imgRel
          if (Test-HudPath $cand) { $imgAbs = $cand }
        }
        $opt = @{
          id = [string]$o.id; label = [string]$o.label; emoji = [string]$o.emoji
          categoryId = [string]$cat.id; categoryLabel = [string]$cat.label
          kind = $kind
          imagePath = $imgAbs
          markerColor = [string]$o.markerColor; borderColor = [string]$o.borderColor
          fillColor = [string]$o.fillColor; textColor = [string]$o.textColor
          lookFx = [string]$o.lookFx
          swatches = @($o.swatches)
        }
        [void]$catObj.options.Add($opt)
        [void]$ui.themeOptions.Add($opt)
      }
      [void]$ui.themeCategories.Add($catObj)
    }
  }
  if ($ui.themeOptions.Count -eq 0) {
    $fallback = @{
      id = 'pastel-rose'; label = 'Rose'; emoji = '🌸'; categoryId = 'pastel'; categoryLabel = 'Pastell'
      kind = 'look'; imagePath = ''
      markerColor = '#f7a8c4'; borderColor = '#c9b6e4'; fillColor = '#2a2430'; textColor = '#f5e6f0'
      swatches = @('#f7a8c4', '#c9b6e4', '#a8e0d0', '#f5e6f0')
    }
    [void]$ui.themeOptions.Add($fallback)
    [void]$ui.themeCategories.Add(@{ id = 'pastel'; label = 'Pastell'; kind = 'look'; options = @($fallback) })
  }
  Convert-LegacyLookBundle
  if (-not [string]::IsNullOrWhiteSpace([string]$script:prefs.lookId)) {
    $ui.selectedThemeId = [string]$script:prefs.lookId
  }
}

# --- Left Card: Box-Model & Mini-Preview ---
$boxCard = New-HudSectionPanel -X ([int](14 * $scale)) -Y ([int](122 * $scale)) -Width ([int](248 * $scale)) -Height ([int](400 * $scale)) -Theme $th
$ui.pageEinst.Controls.Add($boxCard)
$ui.leftPane = $boxCard
$ui.boxHost = $boxCard

$lblBox = New-HudLabel -Text (Get-HudT 'settings.boxModel') -Fore $th.AccentCyan -Font (New-HudFont 'Segoe UI Semibold' ([float](10.5 * $scale)) ([System.Drawing.FontStyle]::Bold)) -AutoSize
$lblBox.Location = New-Object System.Drawing.Point(([int](16 * $scale)), ([int](16 * $scale)))
$boxCard.Controls.Add($lblBox)
$ui.lblBox = $lblBox

$boxFrame = New-Object System.Windows.Forms.Panel
$boxFrame.Size = New-Object System.Drawing.Size(([int](216 * $scale)), ([int](160 * $scale)))
$boxFrame.Location = New-Object System.Drawing.Point(([int](16 * $scale)), ([int](46 * $scale)))
$boxFrame.Padding = New-Object System.Windows.Forms.Padding(([int](10 * $scale)))
Add-HudSubPanelHairline $boxFrame $th
$boxCard.Controls.Add($boxFrame)
$ui.boxFrame = $boxFrame

$miniPreview = New-Object System.Windows.Forms.PictureBox
$miniPreview.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
$miniPreview.Size = New-Object System.Drawing.Size(([int](216 * $scale)), ([int](88 * $scale)))
$miniPreview.Location = New-Object System.Drawing.Point(([int](16 * $scale)), ([int](220 * $scale)))
$miniPreview.BackColor = [System.Drawing.Color]::FromArgb(16, 20, 28)
$miniPreview.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$miniPreview.Padding = New-Object System.Windows.Forms.Padding(2)
$boxCard.Controls.Add($miniPreview)
$ui.miniPreview = $miniPreview

$pnlMargin = New-Object System.Windows.Forms.Panel
$pnlMargin.Tag = 'margin'; $pnlMargin.Dock = [System.Windows.Forms.DockStyle]::Fill
$pnlMargin.BackColor = $ui.colMargin; $pnlMargin.Padding = New-Object System.Windows.Forms.Padding(12)
$boxFrame.Controls.Add($pnlMargin)

$pnlBorder = New-Object System.Windows.Forms.Panel
$pnlBorder.Tag = 'border'; $pnlBorder.Dock = [System.Windows.Forms.DockStyle]::Fill
$pnlBorder.BackColor = $ui.colBorder; $pnlBorder.Padding = New-Object System.Windows.Forms.Padding(10)
$pnlMargin.Controls.Add($pnlBorder)

$pnlPadding = New-Object System.Windows.Forms.Panel
$pnlPadding.Tag = 'padding'; $pnlPadding.Dock = [System.Windows.Forms.DockStyle]::Fill
$pnlPadding.BackColor = $ui.colPadding; $pnlPadding.Padding = New-Object System.Windows.Forms.Padding(12)
$pnlBorder.Controls.Add($pnlPadding)

$pnlContent = New-Object System.Windows.Forms.Panel
$pnlContent.Tag = 'content'; $pnlContent.Dock = [System.Windows.Forms.DockStyle]::Fill
$pnlContent.BackColor = $ui.colContent
$pnlPadding.Controls.Add($pnlContent)

$lblContent = New-Object System.Windows.Forms.Label
$lblContent.UseMnemonic = $false
$lblContent.Text = 'Content'; $lblContent.Tag = 'content'
$lblContent.Dock = [System.Windows.Forms.DockStyle]::Fill
$lblContent.AutoSize = $false
$lblContent.AutoEllipsis = $true
$lblContent.UseCompatibleTextRendering = $false
$lblContent.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblContent.BackColor = $ui.colContent
$lblContent.ForeColor = [System.Drawing.Color]::FromArgb(30, 36, 48)
$lblContent.Padding = New-Object System.Windows.Forms.Padding(1)
$pnlContent.Controls.Add($lblContent)

$boxMarker = New-Object System.Windows.Forms.PictureBox
$boxMarker.Tag = 'content'
$boxMarker.Dock = [System.Windows.Forms.DockStyle]::Left
$boxMarker.Width = [int](32 * $scale)
$boxMarker.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
$boxMarker.BackColor = $ui.colContent
$boxMarker.Margin = New-Object System.Windows.Forms.Padding(2)
$pnlContent.Controls.Add($boxMarker)
try { $pnlContent.Controls.SetChildIndex($boxMarker, ($pnlContent.Controls.Count - 1)) } catch { }
$ui.boxMarker = $boxMarker

$ui.pnlMargin = $pnlMargin; $ui.pnlBorder = $pnlBorder
$ui.pnlPadding = $pnlPadding; $ui.pnlContent = $pnlContent; $ui.lblContent = $lblContent

$boxFrame.Add_Resize({ Layout-BoxModel })
$pnlContent.Add_Resize({
  if ($ui.presetMode) {
    $tid = [string]$ui.selectedThemeId
    $thFit = Get-ThemeById $tid
    $nm = if ($thFit -and $thFit.label) { [string]$thFit.label } else { Get-HudT 'settings.lookPreset' }
    Fit-BoxModelContentLabel $nm
    Update-BoxLookFxImage
  } else {
    $coreFit = if ($script:lastLabelCore) { [string]$script:lastLabelCore } else { 'Content' }
    Fit-BoxModelContentLabel $coreFit
    Update-BoxModelMarker
  }
})

$layerClick = {
  param($s, $e)
  $tag = [string]$s.Tag
  if ($tag) { Highlight-Layer $tag }
}
foreach ($p in @($pnlMargin, $pnlBorder, $pnlPadding, $pnlContent, $lblContent, $boxMarker)) {
  $p.Add_Click($layerClick)
}
