# Copyright (c) 2026 ready-4-it
# AI Keep Clean CCC — Pill visual layer: Apply-PrefsVisual, Place-PillMarkerAndLabel, Refresh-PillWidth.
# Job: own all form-appearance computation and the marker/label layout pass.
# Caller: winforms-pill.ps1 (dot-sourced after all form controls and $scale are defined).
function Apply-VisualLabelFont([float]$fs, [string]$fam, [string]$fxNow) {
  try { $label.Font = New-Object System.Drawing.Font($fam, $fs, [System.Drawing.FontStyle]::Regular) }
  catch { $label.Font = New-Object System.Drawing.Font('Segoe UI', $fs, [System.Drawing.FontStyle]::Regular) }
  $label.AutoEllipsis = $true
  $label.UseCompatibleTextRendering = ($fxNow -eq 'extrude')
}

function Apply-VisualScopeLabels([System.Drawing.Color]$fill, [float]$fs, [string]$fam, [bool]$showVersion, [string]$fxNow) {
  $tcScope = Parse-HexColor ([string]$script:prefs.textColor)
  $dim = if ($null -ne $tcScope) { [System.Drawing.Color]::FromArgb(180, $tcScope.R, $tcScope.G, $tcScope.B) } else { [System.Drawing.Color]::FromArgb(170, 180, 195) }
  $scopeLabel.BackColor = $fill; $scopeLabel.ForeColor = $dim
  $smallF = [float][Math]::Max(6.5, $fs * 0.62)
  try { $scopeLabel.Font = New-Object System.Drawing.Font($fam, $smallF, [System.Drawing.FontStyle]::Regular) }
  catch { $scopeLabel.Font = New-Object System.Drawing.Font('Segoe UI', ([float]7.0), [System.Drawing.FontStyle]::Regular) }
  $scopeLabel.Height = $script:scopeBandH; $scopeLabel.Visible = $true
  if ($showVersion) {
    $tierLabel.Height = Get-ScopeLineHeight; $tierLabel.Visible = -not [bool]$fxNow
    $tierLabel.BackColor = $fill; $tierLabel.ForeColor = $dim
    try { $tierLabel.Font = New-Object System.Drawing.Font($fam, $smallF, [System.Drawing.FontStyle]::Regular) }
    catch { $tierLabel.Font = New-Object System.Drawing.Font('Segoe UI', ([float]7.0), [System.Drawing.FontStyle]::Regular) }
  } else { $tierLabel.Height = 0; $tierLabel.Visible = $false; $tierLabel.Text = '' }
}

function Apply-VisualMarkerMode([string]$mode, [System.Drawing.Color]$markColor, [int]$markW, [int]$contentH) {
  if ($mode -eq 'image' -and (Test-HudPath ([string]$script:prefs.imagePath))) {
    try {
      $loadedImg = if (Get-Command Read-HudImageBitmap -ErrorAction SilentlyContinue) {
        Read-HudImageBitmap -Path ([string]$script:prefs.imagePath)
      } else {
        $bytes = [System.IO.File]::ReadAllBytes([string]$script:prefs.imagePath)
        $ms = New-Object System.IO.MemoryStream(,$bytes)
        [System.Drawing.Image]::FromStream($ms)
      }
      if ($null -ne $loadedImg) {
        Set-MarkerBoxImage $loadedImg; $markerBox.Visible = $true
        return
      }
      $mode = 'emoji'
    } catch { $mode = 'emoji' }
  } elseif ($mode -eq 'image') { $mode = 'emoji' }
  if ($mode -eq 'pattern') {
    Set-MarkerBoxImage (New-PatternSphereBitmap ([string]$script:prefs.pattern) $markColor $markW); $markerBox.Visible = $true
  } elseif ($mode -eq 'emoji') {
    $em = [string]$script:prefs.markerEmoji; if ([string]::IsNullOrWhiteSpace($em)) { $em = '🔵' }
    Set-MarkerBoxImage (New-EmojiBitmap $em $markW $markColor); $markerBox.Visible = $true
  }
  if (-not $markerBox.Visible) { $strip.Width = [int][Math]::Round(12 * $scale); $strip.Height = $contentH; $strip.BackColor = $markColor; $strip.Visible = $true }
}

function Get-PrefsVisualChrome {
  $bw = [Math]::Max(1, [Math]::Min(8, [int]$script:prefs.borderWidth))
  $padIn = [Math]::Max(2, [Math]::Min(24, [int]$script:prefs.padding))
  $fill = Parse-HexColor ([string]$script:prefs.fillColor)
  if ($null -eq $fill) { $fill = [System.Drawing.Color]::FromArgb(22, 28, 38) }
  $tc = Parse-HexColor ([string]$script:prefs.textColor)
  $bc = Parse-HexColor ([string]$script:prefs.borderColor)
  if ($null -eq $bc) { $bc = $script:accentColor }
  return @{ bw = $bw; padIn = $padIn; fill = $fill; tc = $tc; bc = $bc }
}

function Clear-PrefsVisualMarkerSurfaces {
  $script:lookFxKey = ''
  if ($script:patternBrush) { try { $script:patternBrush.Dispose() } catch { }; $script:patternBrush = $null }
  if ($markerBox.Image) { $markerBox.Image = $null }
  if ($script:markerImage) { try { $script:markerImage.Dispose() } catch { }; $script:markerImage = $null }
  if ($strip.BackgroundImage) { try { $oldS = $strip.BackgroundImage; $strip.BackgroundImage = $null; $oldS.Dispose() } catch { } }
  $markerBox.Visible = $false; $strip.Visible = $false
  $markerBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
}

function Apply-PrefsVisual {
  Enforce-FreeMarkerPrefs
  $fs = [float]([Math]::Max(9, [int]$script:prefs.fontSize) * $scale)
  $fam = Resolve-LabelFontFamily
  $fxNow = if ((Test-HudFeature 'hud.lookPresets') -and (Get-Command Get-HudLookFxName -ErrorAction SilentlyContinue)) { Get-HudLookFxName ([string]$script:prefs.lookFx) } else { '' }
  Apply-VisualLabelFont $fs $fam $fxNow

  $c = Get-PrefsVisualChrome
  $border.Padding = if ($fxNow) { New-Object System.Windows.Forms.Padding(0) } else { New-Object System.Windows.Forms.Padding($c.bw) }
  $inner.BackColor = $c.fill; $form.BackColor = $c.fill
  $inner.Padding = New-Object System.Windows.Forms.Padding(0)
  if ($null -ne $c.tc) { $label.ForeColor = $c.tc }
  $border.BackColor = if ($fxNow) { $c.fill } else { $c.bc }

  $markColor = Resolve-MarkerColor
  $pillH = [Math]::Max($basePillH, [int][Math]::Round(($fs + $c.padIn * 2 + $c.bw * 2 + 14) * 1.15))
  $script:currentPillH = $pillH
  if (-not $script:scopeFooterLines -or [int]$script:scopeFooterLines -lt 1) { $script:scopeFooterLines = 1 }
  $script:scopeBandH = Get-ScopeFooterHeight
  Apply-VisualScopeLabels $c.fill $fs $fam (Test-HudFeature 'hud.chrome.version') $fxNow
  try { $border.BringToFront() } catch { }
  Update-ScopeCaption

  $contentH = [Math]::Max(18, ([Math]::Max(1, $pillH - (2 * $c.bw))) - (2 * $c.padIn))
  $markW = [Math]::Max(24, [Math]::Min($contentH, [int][Math]::Round($contentH * 0.92)))
  Clear-PrefsVisualMarkerSurfaces
  Apply-VisualMarkerMode (Get-DisplayMarkerMode) $markColor $markW $contentH
  Place-PillMarkerAndLabel
  Refresh-PillWidth
  if ((Test-HudFeature 'hud.lookPresets') -and (Get-Command Update-HudLookFxChrome -ErrorAction SilentlyContinue)) { try { Update-HudLookFxChrome } catch { } }
}

# Marker Dock.Left + label Dock.Fill: the name never occupies the orb slot
# (absolute overlay + GDI Padding both failed: text-under-logo or missing orb).
function Set-PillMarkerLabelDock([int]$colW, [int]$gap, [int]$padIn) {
  # Apply Dock assignments for whichever of markerBox / strip / fallback is active.
  if ($markerBox.Visible) {
    $strip.Visible = $false; $strip.Dock = [System.Windows.Forms.DockStyle]::None
    $markerBox.Dock = [System.Windows.Forms.DockStyle]::Left; $markerBox.Width = $colW
    $label.Padding = New-Object System.Windows.Forms.Padding($gap, 0, 0, 0)
    $label.Dock = [System.Windows.Forms.DockStyle]::Fill
  } elseif ($strip.Visible) {
    $markerBox.Visible = $false; $markerBox.Dock = [System.Windows.Forms.DockStyle]::None
    $strip.Dock = [System.Windows.Forms.DockStyle]::Left; $strip.Width = [int][Math]::Round(12 * $scale)
    $label.Padding = New-Object System.Windows.Forms.Padding($gap, 0, 0, 0)
    $label.Dock = [System.Windows.Forms.DockStyle]::Fill
  } else {
    $markerBox.Dock = [System.Windows.Forms.DockStyle]::None; $strip.Dock = [System.Windows.Forms.DockStyle]::None
    $label.Padding = New-Object System.Windows.Forms.Padding($padIn, 0, 0, 0)
    $label.Dock = [System.Windows.Forms.DockStyle]::Fill
  }
  try { $inner.Controls.SetChildIndex($label, 0) } catch { }
  if ($strip.Visible) { try { $inner.Controls.SetChildIndex($strip, 1) } catch { } }
  if ($markerBox.Visible) { try { $inner.Controls.SetChildIndex($markerBox, ($inner.Controls.Count - 1)) } catch { } }
}

function Place-PillMarkerAndLabel {
  if ($script:pillInnerLayoutBusy) { $script:pillInnerLayoutPending = $true; return }
  $script:pillInnerLayoutBusy = $true; $script:pillInnerLayoutPending = $false
  $padIn = [Math]::Max(2, [Math]::Min(24, [int]$script:prefs.padding))
  $mar = [Math]::Max(0, [Math]::Min(24, [int]$script:prefs.margin))
  $innerH = [Math]::Max(18, $inner.ClientSize.Height)
  if ($innerH -lt 20) { $innerH = [Math]::Max(18, $script:currentPillH - 4) }
  $contentH = [Math]::Max(18, $innerH - (2 * $padIn))
  $markW = [Math]::Max(24, [Math]::Min($contentH, [int][Math]::Round($contentH * 0.92)))
  $markX = $padIn + [Math]::Max(0, [Math]::Min(12, $mar))
  $gap = [Math]::Max(8, [int][Math]::Round(10 * $scale))
  $colW = $markX + $markW
  $inner.SuspendLayout()
  try {
    $inner.Padding = New-Object System.Windows.Forms.Padding(0, $padIn, 8, $padIn)
    $label.Anchor = [System.Windows.Forms.AnchorStyles]::None; $label.AutoSize = $false
    $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    try { $label.BackColor = $inner.BackColor } catch { }
    try { $markerBox.BackColor = $inner.BackColor } catch { }
    $markerBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    Set-PillMarkerLabelDock $colW $gap $padIn
  } finally { try { $inner.ResumeLayout($true) } catch { }; $script:pillInnerLayoutBusy = $false }
  if ($script:pillInnerLayoutPending) { Place-PillMarkerAndLabel }
  if ((Test-HudFeature 'hud.lookPresets') -and (Get-Command Update-HudLookFxChrome -ErrorAction SilentlyContinue)) { try { Update-HudLookFxChrome } catch { } }
  # Do not `return $textPad` — pipeline output from a WinForms handler
  # raises PipelineStoppedException ("Die Pipeline wurde beendet") and kills the HUD.
}

# Re-indent name when the pill width/height settles (Settings close, host switch).
$script:pillInnerLayoutBusy = $false
$script:pillInnerLayoutPending = $false
$inner.add_Resize({
  try { Place-PillMarkerAndLabel } catch { }
})

function Refresh-PillWidth {
  $text = $label.Text
  if ([string]::IsNullOrEmpty($text)) { $text = 'HUD' }
  $padInEst = [Math]::Max(2, [Math]::Min(24, [int]$script:prefs.padding))
  $marEst = [Math]::Max(0, [Math]::Min(24, [int]$script:prefs.margin))
  $gapEst = [Math]::Max(8, [int][Math]::Round(10 * $scale))
  $innerHEst = [Math]::Max(18, $inner.ClientSize.Height)
  if ($innerHEst -lt 20) { $innerHEst = [Math]::Max(18, $script:currentPillH - 4) }
  $contentHEst = [Math]::Max(18, $innerHEst - (2 * $padInEst))
  $markWEst = [Math]::Max(24, [Math]::Min($contentHEst, [int][Math]::Round($contentHEst * 0.92)))
  # Absolute label.Left owns the indent past the orb (Dock.Fill + Padding is unreliable).
  $left = $padInEst + [Math]::Max(0, [Math]::Min(12, $marEst)) + $markWEst + $gapEst
  $minW = [int][Math]::Round(200 * $scale)
  $maxW = [int][Math]::Round(480 * $scale)
  $flags = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPadding
  
  $lines = $text.Split("`n")
  $lineCount = $lines.Count
  $isMulti = ($lineCount -gt 1)
  if (-not $isMulti) {
    $flags = [System.Windows.Forms.TextFormatFlags]::SingleLine -bor [System.Windows.Forms.TextFormatFlags]::NoPadding
  }

  $measured = [System.Windows.Forms.TextRenderer]::MeasureText($text, $label.Font, (New-Object System.Drawing.Size($maxW, 4096)), $flags)
  $proChrome = Test-HudProChrome
  $script:scopeBandH = Get-ScopeFooterHeight
  $lineH = Get-ScopeLineHeight
  $need = [Math]::Min($maxW, [Math]::Max($minW, $left + $measured.Width + 20))
  
  $extraH = if ($isMulti) { [int]((20 * ($lineCount - 1)) * $scale) } else { 0 }
  $targetPillH = $script:currentPillH + $extraH
  # Dock.Fill owns middle height — do not set $border.Height (that caused the Gemini height bug).
  $strip.Height = [Math]::Max(10, $targetPillH - 4)
  $topBand = if ($proChrome) { $lineH } else { 0 }
  $wantH = [int]($targetPillH + $topBand + $script:scopeBandH)
  
  if ($form.IsHandleCreated) {
    [CccHudWin]::SizeNoActivate($form.Handle, $need, $wantH)
    $form.ClientSize = New-Object System.Drawing.Size($need, $wantH)
    $form.PerformLayout()
  } else {
    $form.Width = $need
    $form.Height = $wantH
    $form.PerformLayout()
  }
  $label.AutoEllipsis = $true
  Place-PillMarkerAndLabel
  $scopeLabel.Height = $script:scopeBandH
  if ($proChrome) {
    $tierLabel.Height = $lineH
  } else {
    $tierLabel.Height = 0
  }
  if (($script:shown -or ($form.Visible -and $form.Left -gt -10000)) -and (-not $script:dragging)) {
    $liveAnchor = $script:agentsRect
    if ($script:agentsHwnd -ne [IntPtr]::Zero -and [CccHudWin]::IsWindow($script:agentsHwnd)) {
      $rLive = New-Object CccHudWin+RECT
      if ([CccHudWin]::GetVisibleWindowRect($script:agentsHwnd, [ref]$rLive) -and ($rLive.Right -gt $rLive.Left)) {
        $liveAnchor = $rLive
        $script:agentsRect = $rLive
      }
    }
    if ($null -ne $liveAnchor -and ($liveAnchor.Right -gt $liveAnchor.Left)) {
      Place-OnAgents $liveAnchor
    } elseif ($form.IsHandleCreated -and $form.Left -gt -10000) {
      $clamped = Clamp-PillPointToScreen $form.Left $form.Top $form.Width $form.Height $null
      if ($clamped.X -ne $form.Left -or $clamped.Y -ne $form.Top) {
        [CccHudWin]::MoveNoActivate($form.Handle, [int]$clamped.X, [int]$clamped.Y)
        $script:lastPlacedX = [int]$clamped.X
        $script:lastPlacedY = [int]$clamped.Y
      }
    }
  }
}

function Resolve-MarkerColor {
  $mc = Parse-HexColor ([string]$script:prefs.markerColor)
  if ($null -ne $mc) { return $mc }
  return $script:accentColor
}

function Get-MarkerColor {
  return (Resolve-MarkerColor)
}

function Apply-SizePreset([string]$id) {
  switch ($id.ToUpperInvariant()) {
    'S' {
      $script:prefs.fontSize = 10
      $script:prefs.padding = 6
      $script:prefs.borderWidth = 1
      $script:prefs.margin = 2
      $script:prefs.sizePreset = 'S'
    }
    'L' {
      $script:prefs.fontSize = 13
      $script:prefs.padding = 10
      $script:prefs.borderWidth = 3
      $script:prefs.margin = 6
      $script:prefs.sizePreset = 'L'
    }
    default {
      $script:prefs.fontSize = 11
      $script:prefs.padding = 8
      $script:prefs.borderWidth = 2
      $script:prefs.margin = 4
      $script:prefs.sizePreset = 'M'
    }
  }
}

function Resolve-LabelFontFamily {
  $fam = [string]$script:prefs.fontFamily
  if ([string]::IsNullOrWhiteSpace($fam)) { return 'Segoe UI' }
  # Emoji fonts render Latin glyphs poorly (fuzzy / bitmap-ish) — never use for pill text.
  if ($fam -match '(?i)emoji|seguiemj') { return 'Segoe UI' }
  return $fam
}