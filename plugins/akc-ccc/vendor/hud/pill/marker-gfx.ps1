# Copyright (c) 2026 ready-4-it
# AI Keep Clean CCC — Marker and sphere bitmap rendering, color utilities.
# Job: own Parse-HexColor, Color-ToHex, Test-HudPath, pattern/sphere/emoji bitmap factories, and
#      Set-MarkerBoxImage (bridges the bitmap pipeline to the $markerBox PictureBox).
# Caller: winforms-pill.ps1 (dot-sourced after System.Drawing is loaded; called after form controls exist).

function Parse-HexColor([string]$hex) {
  if ([string]::IsNullOrWhiteSpace($hex)) { return $null }
  $h = $hex.Trim().TrimStart('#')
  if ($h.Length -eq 3) {
    $h = ($h[0].ToString() + $h[0] + $h[1] + $h[1] + $h[2] + $h[2])
  }
  if ($h.Length -lt 6) { return $null }
  $r = [Convert]::ToInt32($h.Substring(0, 2), 16)
  $g = [Convert]::ToInt32($h.Substring(2, 2), 16)
  $b = [Convert]::ToInt32($h.Substring(4, 2), 16)
  return [System.Drawing.Color]::FromArgb($r, $g, $b)
}

function Test-HudPath([string]$path) {
  if ([string]::IsNullOrWhiteSpace($path)) { return $false }
  try { return [bool](Test-Path -LiteralPath $path) } catch { return $false }
}

function Color-ToHex([System.Drawing.Color]$c) {
  return ('#{0:X2}{1:X2}{2:X2}' -f $c.R, $c.G, $c.B)
}

function New-PatternBrush([string]$pattern, [System.Drawing.Color]$accent, [int]$w, [int]$h) {
  $bmp = New-Object System.Drawing.Bitmap ([Math]::Max(8, $w)), ([Math]::Max(8, $h))
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear($accent)
  $ink = [System.Drawing.Color]::FromArgb(230, 12, 14, 18)
  $chalk = [System.Drawing.Color]::FromArgb(240, 255, 255, 255)
  $penInk = New-Object System.Drawing.Pen $ink, 3
  $penChalk = New-Object System.Drawing.Pen $chalk, 2
  $brInk = New-Object System.Drawing.SolidBrush $ink
  $brChalk = New-Object System.Drawing.SolidBrush $chalk
  switch ($pattern) {
    'dots' {
      for ($y = 5; $y -lt $h; $y += 10) {
        for ($x = 5; $x -lt $w; $x += 10) {
          $g.FillEllipse($brChalk, $x, $y, 5, 5)
          $g.FillEllipse($brInk, ($x + 1), ($y + 1), 3, 3)
        }
      }
    }
    'solid' {
      $g.Clear($accent)
      $g.FillRectangle($brChalk, 0, 0, 4, $h)
    }
    'chevron' {
      for ($y = -4; $y -lt $h + 8; $y += 12) {
        $g.DrawLines($penChalk, @(
          (New-Object System.Drawing.Point 2, ($y + 10)),
          (New-Object System.Drawing.Point ([int]($w / 2)), $y),
          (New-Object System.Drawing.Point ($w - 2), ($y + 10))
        ))
        $g.DrawLines($penInk, @(
          (New-Object System.Drawing.Point 2, ($y + 12)),
          (New-Object System.Drawing.Point ([int]($w / 2)), ($y + 2)),
          (New-Object System.Drawing.Point ($w - 2), ($y + 12))
        ))
      }
    }
    'grid' {
      for ($x = 0; $x -lt $w; $x += 8) { $g.DrawLine($penChalk, $x, 0, $x, $h) }
      for ($y = 0; $y -lt $h; $y += 8) { $g.DrawLine($penInk, 0, $y, $w, $y) }
    }
    default {
      for ($i = - $h; $i -lt $w + $h; $i += 10) {
        $g.DrawLine($penChalk, $i, 0, $i + $h, $h)
        $g.DrawLine($penInk, ($i + 4), 0, ($i + 4 + $h), $h)
      }
    }
  }
  $g.Dispose(); $penInk.Dispose(); $penChalk.Dispose(); $brInk.Dispose(); $brChalk.Dispose()
  return $bmp
}

function Add-SphereBase([System.Drawing.Graphics]$g, [int]$size, [System.Drawing.Color]$accent) {
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $pad = 1
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddEllipse($pad, $pad, ($size - 2 * $pad - 1), ($size - 2 * $pad - 1))
  $pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
  $lr = [Math]::Min(255, $accent.R + 90)
  $lg = [Math]::Min(255, $accent.G + 90)
  $lb = [Math]::Min(255, $accent.B + 90)
  $dr = [Math]::Max(0, [int]($accent.R * 0.28))
  $dg = [Math]::Max(0, [int]($accent.G * 0.28))
  $db = [Math]::Max(0, [int]($accent.B * 0.28))
  $pgb.CenterColor = [System.Drawing.Color]::FromArgb(255, $lr, $lg, $lb)
  $pgb.SurroundColors = @([System.Drawing.Color]::FromArgb(255, $dr, $dg, $db))
  $pgb.CenterPoint = New-Object System.Drawing.PointF(($size * 0.34), ($size * 0.30))
  $g.FillPath($pgb, $path)
  $rim = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(160, 255, 255, 255)), 1.2
  $g.DrawEllipse($rim, $pad, $pad, ($size - 2 * $pad - 1), ($size - 2 * $pad - 1))
  $shade = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(90, 0, 0, 0)), 1.5
  $g.DrawArc($shade, ($pad + 1), ($pad + 1), ($size - 2 * $pad - 3), ($size - 2 * $pad - 3), 20, 160)
  $pgb.Dispose(); $path.Dispose(); $rim.Dispose(); $shade.Dispose()
}

function New-OpaqueMarkerBitmap([System.Drawing.Image]$src, [System.Drawing.Color]$bg) {
  if ($null -eq $src) { return $null }
  $w = [Math]::Max(1, $src.Width)
  $h = [Math]::Max(1, $src.Height)
  $out = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($out)
  try {
    $g.Clear($bg)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($src, 0, 0, $w, $h)
  } finally {
    $g.Dispose()
  }
  return $out
}

function Copy-HudMarkerAlpha([System.Drawing.Image]$src) {
  if ($null -eq $src) { return $null }
  $w = [Math]::Max(1, $src.Width)
  $h = [Math]::Max(1, $src.Height)
  $out = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($out)
  try {
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBilinear
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($src, 0, 0, $w, $h)
  } finally {
    $g.Dispose()
  }
  return $out
}

function Set-MarkerBoxImage([System.Drawing.Image]$src) {
  $alpha = Copy-HudMarkerAlpha $src
  $bg = $inner.BackColor
  $fill = Parse-HexColor ([string]$script:prefs.fillColor)
  if ($null -ne $fill -and ($bg.A -lt 250 -or ($bg.R -lt 12 -and $bg.G -lt 12 -and $bg.B -lt 12))) { $bg = $fill }
  $flatSrc = if ($null -ne $alpha) { $alpha } else { $src }
  $flat = New-OpaqueMarkerBitmap $flatSrc $bg
  if ($null -ne $src -and -not [object]::ReferenceEquals($src, $flat) -and -not [object]::ReferenceEquals($src, $alpha)) {
    try { $src.Dispose() } catch { }
  }
  if ($script:markerImage -and -not [object]::ReferenceEquals($script:markerImage, $alpha)) {
    try { $script:markerImage.Dispose() } catch { }
  }
  $script:markerImage = $alpha
  $markerBox.Image = $flat
}

function New-EmojiBitmap([string]$emoji, [int]$size, [System.Drawing.Color]$bg) {
  # Sphere gradient + emoji glyph (mix: 3D body, flat icon; dark glyph when sphere is near-white)
  $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear([System.Drawing.Color]::Transparent)
  Add-SphereBase $g $size $bg
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $fontPx = [float][Math]::Max(10, ($size * 0.52))
  try {
    $font = New-Object System.Drawing.Font('Segoe UI Emoji', $fontPx, [System.Drawing.FontStyle]::Regular)
  } catch {
    $font = New-Object System.Drawing.Font('Segoe UI', $fontPx, [System.Drawing.FontStyle]::Regular)
  }
  $sf = New-Object System.Drawing.StringFormat
  $sf.Alignment = [System.Drawing.StringAlignment]::Center
  $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
  $rect = New-Object System.Drawing.RectangleF(0, ([float]($size * 0.04)), $size, $size)
  $brightBg = ((($bg.R * 299) + ($bg.G * 587) + ($bg.B * 114)) -gt 185000)
  $shadowCol = if ($brightBg) { [System.Drawing.Color]::FromArgb(140, 255, 255, 255) } else { [System.Drawing.Color]::FromArgb(90, 0, 0, 0) }
  $glyphCol  = if ($brightBg) { [System.Drawing.Color]::FromArgb(255, 18, 22, 30) } else { [System.Drawing.Color]::White }
  $shadow = New-Object System.Drawing.SolidBrush $shadowCol
  $glyph  = New-Object System.Drawing.SolidBrush $glyphCol
  $g.DrawString($emoji, $font, $shadow, (New-Object System.Drawing.RectangleF(1, ([float]($size * 0.06)), $size, $size)), $sf)
  $g.DrawString($emoji, $font, $glyph, $rect, $sf)
  $g.Dispose(); $font.Dispose(); $sf.Dispose(); $shadow.Dispose(); $glyph.Dispose()
  return $bmp
}

function New-PatternSphereBitmap([string]$pattern, [System.Drawing.Color]$accent, [int]$size) {
  # Mix: sphere body + clipped pattern overlay
  $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear([System.Drawing.Color]::Transparent)
  Add-SphereBase $g $size $accent
  $pat = New-PatternBrush $pattern $accent $size $size
  $clip = New-Object System.Drawing.Drawing2D.GraphicsPath
  $clip.AddEllipse(2, 2, ($size - 5), ($size - 5))
  $g.SetClip($clip)
  $g.DrawImage($pat, 0, 0, $size, $size)
  $g.ResetClip()
  $rim = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(140, 255, 255, 255)), 1.2
  $g.DrawEllipse($rim, 1, 1, ($size - 3), ($size - 3))
  $g.Dispose(); $pat.Dispose(); $clip.Dispose(); $rim.Dispose()
  return $bmp
}
