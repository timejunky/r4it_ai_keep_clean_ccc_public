# Copyright (c) 2026 ready-4-it
# Settings dialog marker + shared HUD logo bitmap decoder (PNG/JPG/BMP/GIF/ICO/WebP, 32bppArgb, unlocked file).

function ConvertTo-HudArgbBitmap {
  param([System.Drawing.Image]$Source)
  if ($null -eq $Source) { return $null }
  $w = [Math]::Max(1, [int]$Source.Width)
  $h = [Math]::Max(1, [int]$Source.Height)
  $bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  try {
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($Source, 0, 0, $w, $h)
    $g.Flush()
  } finally {
    $g.Dispose()
  }
  return $bmp
}

function Read-HudImageBitmap {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $bytes = $null
  try { $bytes = [System.IO.File]::ReadAllBytes($Path) } catch { return $null }
  if ($null -eq $bytes -or $bytes.Length -lt 8) { return $null }

  # 1) Standard GDI+ decode -> detached 32bppArgb Bitmap
  $ms = $null
  $img = $null
  try {
    $ms = New-Object System.IO.MemoryStream(,$bytes)
    $img = [System.Drawing.Image]::FromStream($ms)
    return (ConvertTo-HudArgbBitmap -Source $img)
  } catch {
  } finally {
    if ($null -ne $img) { try { $img.Dispose() } catch { } }
    if ($null -ne $ms) { try { $ms.Dispose() } catch { } }
  }

  # 2) ICO fallback via System.Drawing.Icon
  if ($Path -match '(?i)\.ico$') {
    $msIco = $null
    $ico = $null
    $icoBmp = $null
    try {
      $msIco = New-Object System.IO.MemoryStream(,$bytes)
      $ico = New-Object System.Drawing.Icon($msIco, 128, 128)
      $icoBmp = $ico.ToBitmap()
      return (ConvertTo-HudArgbBitmap -Source $icoBmp)
    } catch {
    } finally {
      if ($null -ne $icoBmp) { try { $icoBmp.Dispose() } catch { } }
      if ($null -ne $ico) { try { $ico.Dispose() } catch { } }
      if ($null -ne $msIco) { try { $msIco.Dispose() } catch { } }
    }
  }

  # 3) WIC fallback via WPF PresentationCore (WebP / 256px PNG-compressed ICO)
  $msWic = $null
  $msPng = $null
  $wicImg = $null
  try {
    if (-not ('System.Windows.Media.Imaging.BitmapDecoder' -as [type])) {
      Add-Type -AssemblyName PresentationCore -ErrorAction Stop
    }
    $msWic = New-Object System.IO.MemoryStream(,$bytes)
    $dec = [System.Windows.Media.Imaging.BitmapDecoder]::Create(
      $msWic,
      [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat,
      [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
    )
    if ($dec -and $dec.Frames -and $dec.Frames.Count -gt 0) {
      $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
      $enc.Frames.Add($dec.Frames[0])
      $msPng = New-Object System.IO.MemoryStream
      $enc.Save($msPng)
      [void]$msPng.Seek(0, [System.IO.SeekOrigin]::Begin)
      $wicImg = [System.Drawing.Image]::FromStream($msPng)
      return (ConvertTo-HudArgbBitmap -Source $wicImg)
    }
  } catch {
  } finally {
    if ($null -ne $wicImg) { try { $wicImg.Dispose() } catch { } }
    if ($null -ne $msPng) { try { $msPng.Dispose() } catch { } }
    if ($null -ne $msWic) { try { $msWic.Dispose() } catch { } }
  }
  return $null
}

function New-HudDialogMarkerBitmap {
  param([int]$Size = 32)
  $size = [Math]::Max(16, [Math]::Min(160, [int]$Size))
  $mark = [System.Drawing.Color]::FromArgb(90, 209, 232)
  if (Get-Command Get-MarkerColor -ErrorAction SilentlyContinue) {
    try { $mark = Get-MarkerColor } catch { }
  }
  $mode = ''
  try { $mode = [string]$script:prefs.markerMode } catch { $mode = '' }
  if ($mode -eq 'pattern' -and (Get-Command New-PatternSphereBitmap -ErrorAction SilentlyContinue)) {
    $pat = 'stripes'
    try { if (-not [string]::IsNullOrWhiteSpace([string]$script:prefs.pattern)) { $pat = [string]$script:prefs.pattern } } catch { }
    return New-PatternSphereBitmap $pat $mark $size
  }
  if ($mode -eq 'image') {
    $path = ''
    try { $path = [string]$script:prefs.imagePath } catch { $path = '' }
    $img = Read-HudImageBitmap -Path $path
    if ($null -ne $img) {
      $bmp = $null
      try {
        $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        try {
          $g.Clear([System.Drawing.Color]::Transparent)
          $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
          if ('HudLookFx' -as [type]) {
            [HudLookFx]::DrawMarker($g, $img, (New-Object System.Drawing.Rectangle 0, 0, $size, $size))
          } else {
            $sw = [Math]::Max(1, $img.Width); $sh = [Math]::Max(1, $img.Height)
            $sc = [Math]::Min(([double]$size / $sw), ([double]$size / $sh))
            $fw = [Math]::Max(1, [int][Math]::Round($sw * $sc))
            $fh = [Math]::Max(1, [int][Math]::Round($sh * $sc))
            $fx = [int](($size - $fw) / 2); $fy = [int](($size - $fh) / 2)
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBilinear
            $g.DrawImage($img, $fx, $fy, $fw, $fh)
          }
          $g.Flush()
        } finally { $g.Dispose() }
        return $bmp
      } catch {
        if ($null -ne $bmp) { try { $bmp.Dispose() } catch { } }
      } finally {
        try { $img.Dispose() } catch { }
      }
    }
  }
  $em = '🔵'
  try { if (-not [string]::IsNullOrWhiteSpace([string]$script:prefs.markerEmoji)) { $em = [string]$script:prefs.markerEmoji } } catch { }
  if (Get-Command New-EmojiBitmap -ErrorAction SilentlyContinue) {
    return New-EmojiBitmap $em $size $mark
  }
  return $null
}
