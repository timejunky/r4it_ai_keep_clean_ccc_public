# Copyright (c) 2026 ready-4-it
# Glass panel paint — one job: chrome vs content (-Content) surfaces.
# Dot-sourced from winforms-theme.ps1. Callers that pass -Content need this switch.

function Add-HudGlassPaint {
  param(
    [Parameter(Mandatory)]$Control,
    $Theme = (Get-HudTheme),
    [switch]$WithGrid,
    [switch]$UseBitmapBackground,
    [switch]$NoWatermark,
    # Scroll/settings content: same glass gradient, no bevel/lattice (readable + uniform).
    [switch]$Content
  )
  # CSS .ccc-glass-panel — pure GDI gradients (Weg A port).
  # Do NOT stretch rit_akc_ccc_bg.png here: that asset is a full chrome mockup
  # (2016x2082) and produces the broken "metal top / glass bottom" look when stretched.
  if ($null -eq $Control.Tag) { $Control.Tag = @{} }
  if ($Control.Tag -is [hashtable]) {
    $Control.Tag.Theme = $Theme
    $Control.Tag.WithGrid = [bool]$WithGrid
    $Control.Tag.UseBmp = [bool]$UseBitmapBackground
    $Control.Tag.NoWatermark = [bool]$NoWatermark
    $Control.Tag.Content = [bool]$Content
    $Control.Tag.IsGlassSurface = $true
  } else {
    $Control.Tag = @{
      Theme = $Theme
      WithGrid = [bool]$WithGrid
      UseBmp = [bool]$UseBitmapBackground
      NoWatermark = [bool]$NoWatermark
      Content = [bool]$Content
      IsGlassSurface = $true
    }
  }
  $Control.BackgroundImage = $null
  Enable-HudDoubleBuffer -Control $Control
  if ($Content -and $Control.AutoScroll) {
    $Control.Add_Scroll({ param($s, $e) $s.Invalidate() })
  }
  $Control.Add_Resize({
    param($s, $e)
    if ($s.Tag -is [hashtable] -and $s.Tag.GlassCache) {
      try { $s.Tag.GlassCache.Dispose() } catch { }
      $s.Tag.GlassCache = $null
    }
  })
  $Control.Add_Paint({
    param($s, $e)
    $th = if ($s.Tag -is [hashtable] -and $s.Tag.Theme) { $s.Tag.Theme } else { Get-HudTheme }
    $g = $e.Graphics
    $r = $s.ClientRectangle
    if ($r.Width -lt 2 -or $r.Height -lt 2) { return }

    $isContent = ($s.Tag -is [hashtable] -and $s.Tag.Content)
    # Scroll surfaces: paint glass in document space (offset by AutoScrollPosition)
    # so the gradient does not restart at the viewport top when scrolling.
    if ($isContent -and $s.AutoScroll) {
      $ox = -$s.AutoScrollPosition.X
      $oy = -$s.AutoScrollPosition.Y
      $docH = [Math]::Max($r.Height, [Math]::Max(0, $s.AutoScrollMinSize.Height))
      $g.TranslateTransform($ox, $oy)
      try {
        $rr = New-Object System.Drawing.Rectangle(0, 0, $r.Width, $docH)
        # Opaque dark glass — never wash into metal highlights (white copy stays readable).
        $c0 = [System.Drawing.Color]::FromArgb(0x24, 0x2a, 0x32)
        $c1 = [System.Drawing.Color]::FromArgb(0x1a, 0x1e, 0x24)
        $c2 = [System.Drawing.Color]::FromArgb(0x12, 0x14, 0x18)
        $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rr, $c0, $c2, 160.0)
        $blend = New-Object System.Drawing.Drawing2D.ColorBlend
        $blend.Colors = [System.Drawing.Color[]]@($c0, $c1, $c2)
        $blend.Positions = [float[]]@(0.0, 0.4, 1.0)
        $br.InterpolationColors = $blend
        $g.FillRectangle($br, $rr)
        $br.Dispose()
        $gloss = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
          $rr,
          [System.Drawing.Color]::FromArgb(8, 255, 255, 255),
          [System.Drawing.Color]::FromArgb(0, 255, 255, 255),
          135.0
        )
        $gb = New-Object System.Drawing.Drawing2D.ColorBlend
        $gb.Colors = [System.Drawing.Color[]]@(
          [System.Drawing.Color]::FromArgb(8, 255, 255, 255),
          [System.Drawing.Color]::FromArgb(6, 255, 255, 255),
          [System.Drawing.Color]::FromArgb(0, 255, 255, 255),
          [System.Drawing.Color]::FromArgb(0, 255, 255, 255)
        )
        $gb.Positions = [float[]]@(0.0, 0.45, 0.451, 1.0)
        $gloss.InterpolationColors = $gb
        $g.FillRectangle($gloss, $rr)
        $gloss.Dispose()
      } finally {
        $g.ResetTransform()
      }
      return
    }

    $cache = $null
    if ($s.Tag -is [hashtable]) { $cache = $s.Tag.GlassCache }
    if ($null -eq $cache -or $cache.Width -ne $r.Width -or $cache.Height -ne $r.Height) {
      if ($cache) { try { $cache.Dispose() } catch { } }
      $bmp = New-Object System.Drawing.Bitmap($r.Width, $r.Height)
      $bg = [System.Drawing.Graphics]::FromImage($bmp)
      $bg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
      $bg.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
      $rr = New-Object System.Drawing.Rectangle(0, 0, $r.Width, $r.Height)

      $useBmp = ($s.Tag -is [hashtable] -and $s.Tag.UseBmp)
      $photo = if ($useBmp) { Get-HudBackgroundImage } else { $null }
      if ($photo) {
        $src = New-Object System.Drawing.Rectangle(0, 0, $photo.Width, $photo.Height)
        $scale = [Math]::Max(($rr.Width / [double]$photo.Width), ($rr.Height / [double]$photo.Height))
        $dw = [int]($photo.Width * $scale)
        $dh = [int]($photo.Height * $scale)
        $dx = [int](($rr.Width - $dw) / 2)
        $dy = [int](($rr.Height - $dh) / 2)
        $bg.DrawImage($photo, (New-Object System.Drawing.Rectangle($dx, $dy, $dw, $dh)), $src, [System.Drawing.GraphicsUnit]::Pixel)
        $veil = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 26, 28, 30))
        $bg.FillRectangle($veil, $rr)
        $veil.Dispose()
      } else {
        # Opaque dark glass — never wash into metal highlights (white copy stays readable).
        $c0 = [System.Drawing.Color]::FromArgb(0x24, 0x2a, 0x32)
        $c1 = [System.Drawing.Color]::FromArgb(0x1a, 0x1e, 0x24)
        $c2 = [System.Drawing.Color]::FromArgb(0x12, 0x14, 0x18)
        $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rr, $c0, $c2, 160.0)
        $blend = New-Object System.Drawing.Drawing2D.ColorBlend
        $blend.Colors = [System.Drawing.Color[]]@($c0, $c1, $c2)
        $blend.Positions = [float[]]@(0.0, 0.4, 1.0)
        $br.InterpolationColors = $blend
        $bg.FillRectangle($br, $rr)
        $br.Dispose()
      }

      $isContent = ($s.Tag -is [hashtable] -and $s.Tag.Content)
      if (-not $isContent) {
        for ($i = 0; $i -lt 12; $i++) {
          $a = [int](180 * (($i + 1) / 12.0))
          $penV = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($a, 0, 0, 0), 2)
          $bg.DrawRectangle($penV, $i * 2, $i * 2, ($r.Width - 4 * $i - 1), ($r.Height - 4 * $i - 1))
          $penV.Dispose()
        }
      }

      $gloss = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rr,
        [System.Drawing.Color]::FromArgb($(if ($isContent) { 8 } else { 31 }), 255, 255, 255),
        [System.Drawing.Color]::FromArgb(0, 255, 255, 255),
        135.0
      )
      $gb = New-Object System.Drawing.Drawing2D.ColorBlend
      $gb.Colors = [System.Drawing.Color[]]@(
        [System.Drawing.Color]::FromArgb($(if ($isContent) { 8 } else { 31 }), 255, 255, 255),
        [System.Drawing.Color]::FromArgb($(if ($isContent) { 6 } else { 13 }), 255, 255, 255),
        [System.Drawing.Color]::FromArgb(0, 255, 255, 255),
        [System.Drawing.Color]::FromArgb(0, 255, 255, 255)
      )
      $gb.Positions = [float[]]@(0.0, 0.45, 0.451, 1.0)
      $gloss.InterpolationColors = $gb
      $bg.FillRectangle($gloss, $rr)
      $gloss.Dispose()

      $skipWm = ($s.Tag -is [hashtable] -and $s.Tag.NoWatermark)
      if (-not $skipWm) {
        $wmBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(12, 255, 255, 255))
        $wmFont = New-Object System.Drawing.Font('Segoe UI', ([Math]::Max(28.0, $r.Height / 14.0)), [System.Drawing.FontStyle]::Bold)
        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment = [System.Drawing.StringAlignment]::Center
        $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
        $bg.DrawString("AKC`nCCC", $wmFont, $wmBrush, [System.Drawing.RectangleF]$rr, $sf)
        $sf.Dispose(); $wmFont.Dispose(); $wmBrush.Dispose()
      }

      # Chrome shell keeps diamond lattice; content surfaces stay smooth for type.
      if (-not $isContent) {
        $penGrid = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(10, 255, 255, 255), 1)
        $step = 75
        $diag = $r.Width + $r.Height
        for ($i = -$diag; $i -lt $diag; $i += $step) {
          $bg.DrawLine($penGrid, $i, 0, ($i + $r.Height), $r.Height)
          $bg.DrawLine($penGrid, $i, $r.Height, ($i + $r.Height), 0)
        }
        $penGrid.Dispose()
      }
      $bg.Dispose()
      if ($s.Tag -is [hashtable]) { $s.Tag.GlassCache = $bmp }
      $cache = $bmp
    }
    $g.DrawImageUnscaled($cache, 0, 0)
  })
}
