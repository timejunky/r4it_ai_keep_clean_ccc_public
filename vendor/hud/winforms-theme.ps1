# Copyright (c) 2026 ready-4-it
# AI Keep Clean CCC — HUD visual templates (Gemini glass / metal skin)
# Dot-sourced by winforms-settings.ps1. Keep painting lightweight (GDI+ only).

if (-not ('System.Windows.Forms.Form' -as [type])) {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
}

function Get-HudTheme {
  # Mirrors scripts/hud/assets/ccc_hud_design.css :root (Design SSOT).
  return @{
    AccentCyan       = [System.Drawing.Color]::FromArgb(90, 209, 232)   # #5ad1e8
    AccentCyanDim    = [System.Drawing.Color]::FromArgb(0, 136, 170)    # #0088aa
    ProGold          = [System.Drawing.Color]::FromArgb(230, 190, 90)   # #e6be5a
    TextPrimary      = [System.Drawing.Color]::FromArgb(240, 244, 248)  # #f0f4f8
    TextMuted        = [System.Drawing.Color]::FromArgb(200, 210, 224)  # #c8d2e0
    TextDim          = [System.Drawing.Color]::FromArgb(160, 175, 195)
    GlassDeep        = [System.Drawing.Color]::FromArgb(30, 32, 36)     # #1e2024
    GlassPanel       = [System.Drawing.Color]::FromArgb(32, 40, 52)
    GlassPanelAlt    = [System.Drawing.Color]::FromArgb(28, 34, 44)
    ChromeHi         = [System.Drawing.Color]::FromArgb(224, 228, 232)  # #e0e4e8
    ChromeMid        = [System.Drawing.Color]::FromArgb(155, 160, 166)  # #9ba0a6
    ChromeLo         = [System.Drawing.Color]::FromArgb(74, 78, 84)     # #4a4e54
    MetalTop         = [System.Drawing.Color]::FromArgb(210, 218, 228)
    MetalMid         = [System.Drawing.Color]::FromArgb(150, 160, 175)
    MetalBot         = [System.Drawing.Color]::FromArgb(70, 78, 92)
    PrimaryMetalTop  = [System.Drawing.Color]::FromArgb(120, 190, 220)
    PrimaryMetalMid  = [System.Drawing.Color]::FromArgb(50, 120, 160)
    PrimaryMetalBot  = [System.Drawing.Color]::FromArgb(20, 55, 85)
    BorderHairline   = [System.Drawing.Color]::FromArgb(130, 150, 170)
    MenuBar          = [System.Drawing.Color]::FromArgb(198, 204, 212)
    MenuText         = [System.Drawing.Color]::FromArgb(26, 28, 32)
    Danger           = [System.Drawing.Color]::FromArgb(120, 55, 55)
    Success          = [System.Drawing.Color]::FromArgb(40, 160, 90)
    SpacingBlock     = 15
    PaddingPanel     = 20
  }
}

function New-HudFont([string]$family, [float]$em, [System.Drawing.FontStyle]$style = [System.Drawing.FontStyle]::Regular) {
  return New-Object System.Drawing.Font($family, $em, $style)
}

function Resolve-HudBackgroundPath {
  $cands = @(
    (Join-Path $PSScriptRoot 'assets\rit_akc_ccc_bg.png'),
    (Join-Path $env:USERPROFILE '.cursor\plugins\local\ai-keep-clean-ccc\vendor\hud\assets\rit_akc_ccc_bg.png'),
    (Join-Path $env:USERPROFILE '.cursor\plugins\local\ai-keep-clean-ccc\assets\rit_akc_ccc_bg.png')
  )
  foreach ($c in $cands) {
    try {
      $full = [System.IO.Path]::GetFullPath($c)
      if (Test-Path -LiteralPath $full) { return $full }
    } catch { }
  }
  return $null
}

function Get-HudBackgroundImage {
  if ($script:HudBgImage) { return $script:HudBgImage }
  $path = Resolve-HudBackgroundPath
  if (-not $path) { return $null }
  try {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $ms = New-Object System.IO.MemoryStream(,$bytes)
    $script:HudBgImage = [System.Drawing.Image]::FromStream($ms)
    return $script:HudBgImage
  } catch {
    return $null
  }
}

function Invoke-HudSafeLayout {
  param(
    [Parameter(Mandatory)][scriptblock]$Layout,
    [string]$Key = 'default'
  )
  if (-not $script:HudLayoutBusy) { $script:HudLayoutBusy = @{} }
  if ($script:HudLayoutBusy[$Key]) { return }
  $script:HudLayoutBusy[$Key] = $true
  try {
    & $Layout
  } finally {
    $script:HudLayoutBusy[$Key] = $false
  }
}

function Get-HudStableContentWidth {
  param(
    [Parameter(Mandatory)]$ScrollParent,
    [int]$HorizontalPad = 40,
    [int]$MinWidth = 420
  )
  # Use control Width (not ClientSize) and always reserve the v-scrollbar strip.
  # That stops AutoScroll show/hide from oscillating layout width (~10–20 About flickers).
  $sb = [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth
  $raw = $ScrollParent.Width
  if ($raw -lt 40) { $raw = $ScrollParent.ClientSize.Width }
  return [Math]::Max($MinWidth, ($raw - $HorizontalPad - $sb))
}

function Enable-HudDoubleBuffer {
  param([Parameter(Mandatory)]$Control)
  # Never assign .DoubleBuffered directly — it is protected and crashes WinForms hosts in PS.
  try {
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic
    $prop = $Control.GetType().GetProperty('DoubleBuffered', $flags)
    if ($null -ne $prop -and $prop.CanWrite) {
      $prop.SetValue($Control, $true, $null)
    }
    $setStyle = $Control.GetType().GetMethod('SetStyle', $flags)
    if ($null -ne $setStyle) {
      $style = [System.Windows.Forms.ControlStyles]::AllPaintingInWmPaint -bor
        [System.Windows.Forms.ControlStyles]::UserPaint -bor
        [System.Windows.Forms.ControlStyles]::OptimizedDoubleBuffer -bor
        [System.Windows.Forms.ControlStyles]::ResizeRedraw
      [void]$setStyle.Invoke($Control, @($style, $true))
    }
  } catch { }
}

function Set-HudRedraw {
  param([Parameter(Mandatory)]$Control, [bool]$Enabled)
  # Freeze painting during bulk layout — stops About "wild flicker".
  try {
    if (-not $Control.IsHandleCreated) { return }
    if (-not ('HudNative' -as [type])) {
      Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class HudNative {
  [DllImport("user32.dll")]
  public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);
}
'@
    }
    $WM_SETREDRAW = 0x000B
    [void][HudNative]::SendMessage($Control.Handle, $WM_SETREDRAW, [IntPtr][int]$Enabled, [IntPtr]::Zero)
    if ($Enabled) { $Control.Invalidate($true) }
  } catch { }
}

function Add-HudMetalFramePaint {
  param(
    [Parameter(Mandatory)]$Control,
    $Theme = (Get-HudTheme)
  )
  # CSS: .ccc-metal-frame — brushed metal linear-gradient(135deg, …)
  if ($null -eq $Control.Tag) { $Control.Tag = @{} }
  if ($Control.Tag -is [hashtable]) { $Control.Tag.Theme = $Theme }
  Enable-HudDoubleBuffer -Control $Control
  $Control.Add_Resize({
    param($s, $e)
    if ($s.Tag -is [hashtable] -and $s.Tag.MetalCache) {
      try { $s.Tag.MetalCache.Dispose() } catch { }
      $s.Tag.MetalCache = $null
    }
  })
  $Control.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $r = $s.ClientRectangle
    if ($r.Width -lt 4 -or $r.Height -lt 4) { return }
    $cache = $null
    if ($s.Tag -is [hashtable]) { $cache = $s.Tag.MetalCache }
    if ($null -eq $cache -or $cache.Width -ne $r.Width -or $cache.Height -ne $r.Height) {
      if ($cache) { try { $cache.Dispose() } catch { } }
      $bmp = New-Object System.Drawing.Bitmap($r.Width, $r.Height)
      $bg = [System.Drawing.Graphics]::FromImage($bmp)
      $bg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
      $colors = [System.Drawing.Color[]]@(
        [System.Drawing.Color]::FromArgb(230, 232, 234),
        [System.Drawing.Color]::FromArgb(168, 170, 176),
        [System.Drawing.Color]::FromArgb(245, 247, 248),
        [System.Drawing.Color]::FromArgb(138, 141, 145),
        [System.Drawing.Color]::FromArgb(209, 211, 214),
        [System.Drawing.Color]::FromArgb(107, 110, 115)
      )
      $positions = [float[]]@(0.0, 0.2, 0.4, 0.6, 0.8, 1.0)
      $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Rectangle(0, 0, $r.Width, $r.Height)),
        $colors[0],
        $colors[$colors.Length - 1],
        135.0
      )
      $blend = New-Object System.Drawing.Drawing2D.ColorBlend
      $blend.Colors = $colors
      $blend.Positions = $positions
      $br.InterpolationColors = $blend
      $bg.FillRectangle($br, 0, 0, $r.Width, $r.Height)
      $br.Dispose()
      $hi = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(180, 255, 255, 255), 1)
      $bg.DrawLine($hi, 0, 1, $r.Width, 1)
      $hi.Dispose()
      $lo = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120, 0, 0, 0), 2)
      $bg.DrawLine($lo, 0, ($r.Height - 2), $r.Width, ($r.Height - 2))
      $lo.Dispose()
      $bg.Dispose()
      if ($s.Tag -is [hashtable]) { $s.Tag.MetalCache = $bmp }
      $cache = $bmp
    }
    $g.DrawImageUnscaled($cache, 0, 0)
  })
}

$__hudGlassPaint = Join-Path $PSScriptRoot 'theme/glass-paint.ps1'
if (Test-Path -LiteralPath $__hudGlassPaint) { . $__hudGlassPaint }
$__hudDarkInputs = Join-Path $PSScriptRoot 'theme/dark-inputs.ps1'
if (Test-Path -LiteralPath $__hudDarkInputs) { . $__hudDarkInputs }

function New-HudMetalGlassHost {
  param(
    [Parameter(Mandatory)]$Parent,
    $Theme = (Get-HudTheme),
    [float]$Scale = 1.0,
    [switch]$Slim
  )
  # Outer shell: slim chrome (full-window empty glass felt "too large").
  $framePad = if ($Slim) { [Math]::Max(5, [int](6 * $Scale)) } else { [Math]::Max(8, [int](10 * $Scale)) }
  $bezelPad = if ($Slim) { 2 } else { 3 }

  $metal = New-Object System.Windows.Forms.Panel
  $metal.Dock = [System.Windows.Forms.DockStyle]::Fill
  $metal.BackColor = [System.Drawing.Color]::FromArgb(0xa8, 0xaa, 0xb0)
  $metal.Padding = New-Object System.Windows.Forms.Padding($framePad)
  Add-HudMetalFramePaint -Control $metal -Theme $Theme
  $Parent.Controls.Add($metal)
  try { $metal.SendToBack() } catch { }

  $bezel = New-Object System.Windows.Forms.Panel
  $bezel.Dock = [System.Windows.Forms.DockStyle]::Fill
  $bezel.BackColor = [System.Drawing.Color]::FromArgb(0x1a, 0x1a, 0x1c)
  $bezel.Padding = New-Object System.Windows.Forms.Padding($bezelPad)
  Enable-HudDoubleBuffer -Control $bezel
  $metal.Controls.Add($bezel)

  $glass = New-Object System.Windows.Forms.Panel
  $glass.Dock = [System.Windows.Forms.DockStyle]::Fill
  $glass.BackColor = [System.Drawing.Color]::FromArgb(0x1a, 0x1c, 0x1e)
  Add-HudGlassPaint -Control $glass -Theme $Theme -NoWatermark -Content
  $bezel.Controls.Add($glass)
  return $glass
}

function New-HudMetalGlassCard {
  param(
    $Theme = (Get-HudTheme),
    [float]$Scale = 1.0,
    [int]$Width = 520,
    [int]$Height = 560
  )
  # Content-hugging CSS card (metal → bezel → glass). Size to content in layout.
  $framePad = [Math]::Max(10, [int](12 * $Scale))
  $bezelPad = [Math]::Max(3, [int](4 * $Scale))
  $metal = New-Object System.Windows.Forms.Panel
  $metal.Size = New-Object System.Drawing.Size($Width, $Height)
  $metal.BackColor = [System.Drawing.Color]::FromArgb(0xa8, 0xaa, 0xb0)
  $metal.Padding = New-Object System.Windows.Forms.Padding($framePad)
  Enable-HudDoubleBuffer -Control $metal
  Add-HudMetalFramePaint -Control $metal -Theme $Theme

  $bezel = New-Object System.Windows.Forms.Panel
  $bezel.Dock = [System.Windows.Forms.DockStyle]::Fill
  $bezel.BackColor = [System.Drawing.Color]::FromArgb(0x1a, 0x1a, 0x1c)
  $bezel.Padding = New-Object System.Windows.Forms.Padding($bezelPad)
  Enable-HudDoubleBuffer -Control $bezel
  $metal.Controls.Add($bezel)

  $glass = New-Object System.Windows.Forms.Panel
  $glass.Dock = [System.Windows.Forms.DockStyle]::Fill
  $glass.BackColor = [System.Drawing.Color]::FromArgb(0x1a, 0x1c, 0x1e)
  Add-HudGlassPaint -Control $glass -Theme $Theme -WithGrid:$false
  $bezel.Controls.Add($glass)

  return @{
    Metal     = $metal
    Glass     = $glass
    FramePad  = $framePad
    BezelPad  = $bezelPad
    Chrome    = (2 * ($framePad + $bezelPad))
  }
}

function New-HudIndentedBlock {
  param(
    [int]$X, [int]$Y, [int]$Width, [int]$Height,
    $Theme = (Get-HudTheme),
    [int]$Indent = 12
  )
  $p = New-HudSectionPanel -X ($X + $Indent) -Y $Y -Width ([Math]::Max(40, ($Width - $Indent))) -Height $Height -Theme $Theme
  return $p
}

function Add-HudSectionFramePaint {
  param([Parameter(Mandatory)]$Control, $Theme = (Get-HudTheme), [int]$Corner = 14)
  if ($null -eq $Control.Tag) { $Control.Tag = @{} }
  if ($Control.Tag -is [hashtable]) {
    $Control.Tag.Theme = $Theme
    $Control.Tag.Corner = $Corner
  } else {
    $Control.Tag = @{ Theme = $Theme; Corner = $Corner }
  }
  $Control.Add_Paint({
    param($s, $e)
    $th = if ($s.Tag -is [hashtable] -and $s.Tag.Theme) { $s.Tag.Theme } else { Get-HudTheme }
    $cornerLen = 14
    if ($s.Tag -is [hashtable] -and $s.Tag.Corner) { $cornerLen = [int]$s.Tag.Corner }
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $r = $s.ClientRectangle
    if ($r.Width -lt 8 -or $r.Height -lt 8) { return }
    $inset = New-Object System.Drawing.Rectangle(1, 1, ($r.Width - 3), ($r.Height - 3))
    # Opaque glass plate (alpha 255) so white body copy never sits on the metal wash.
    $brSec = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
      $inset,
      [System.Drawing.Color]::FromArgb(255, 28, 34, 44),
      [System.Drawing.Color]::FromArgb(255, 16, 20, 26),
      160.0
    )
    $g.FillRectangle($brSec, $inset)
    $brSec.Dispose()
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(160, $th.BorderHairline), 1)
    $g.DrawRectangle($pen, $inset)
    $pen.Dispose()
    $c = [Math]::Max(8, $cornerLen)
    $penC = New-Object System.Drawing.Pen($th.AccentCyan, 1.6)
    $g.DrawLine($penC, $inset.Left, ($inset.Top + $c), $inset.Left, $inset.Top)
    $g.DrawLine($penC, $inset.Left, $inset.Top, ($inset.Left + $c), $inset.Top)
    $g.DrawLine($penC, ($inset.Right - $c), $inset.Top, $inset.Right, $inset.Top)
    $g.DrawLine($penC, $inset.Right, $inset.Top, $inset.Right, ($inset.Top + $c))
    $g.DrawLine($penC, $inset.Left, ($inset.Bottom - $c), $inset.Left, $inset.Bottom)
    $g.DrawLine($penC, $inset.Left, $inset.Bottom, ($inset.Left + $c), $inset.Bottom)
    $g.DrawLine($penC, ($inset.Right - $c), $inset.Bottom, $inset.Right, $inset.Bottom)
    $g.DrawLine($penC, $inset.Right, ($inset.Bottom - $c), $inset.Right, $inset.Bottom)
    $penC.Dispose()
  })
}

function New-HudSectionPanel {
  param(
    [int]$X, [int]$Y, [int]$Width, [int]$Height,
    $Theme = (Get-HudTheme)
  )
  $p = New-Object System.Windows.Forms.Panel
  $p.Location = New-Object System.Drawing.Point($X, $Y)
  $p.Size = New-Object System.Drawing.Size($Width, $Height)
  # Near-glass card (opaque enough to avoid parent repaint storms)
  $p.BackColor = [System.Drawing.Color]::FromArgb(22, 26, 34)
  Enable-HudDoubleBuffer -Control $p
  Add-HudSectionFramePaint -Control $p -Theme $Theme
  if ($p.Tag -is [hashtable]) { $p.Tag.IsSectionCard = $true }
  return $p
}

function Convert-HudUiUpper([string]$Text) {
  if ([string]::IsNullOrEmpty($Text)) { return $Text }
  $code = 'en'
  try {
    if (Get-Command Get-HudLang -ErrorAction SilentlyContinue) {
      $g = [string](Get-HudLang)
      if (-not [string]::IsNullOrWhiteSpace($g)) { $code = $g }
    }
  } catch { }
  try {
    $cult = [System.Globalization.CultureInfo]::GetCultureInfo($code)
  } catch {
    $cult = [System.Globalization.CultureInfo]::InvariantCulture
  }
  # Culture-aware upper: Turkish i→İ (Invariant would make I / break labels).
  return $Text.ToUpper($cult)
}

function New-HudMetalButton {
  param(
    [string]$Text,
    [int]$Width,
    [int]$Height,
    $Theme = (Get-HudTheme),
    [switch]$AccentGlow,
    [switch]$Primary,
    [switch]$KeepCase,
    [switch]$FixedWidth,
    $Payload = $null
  )
  $usePrimary = $Primary -or $AccentGlow
  $b = New-Object System.Windows.Forms.Button
  $b.UseMnemonic = $false
  if ($KeepCase) {
    $b.Text = $Text
  } else {
    $b.Text = Convert-HudUiUpper $Text
  }
  $b.Width = $Width
  $b.Height = $Height
  $b.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $b.FlatAppearance.BorderSize = 0
  $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::Transparent
  $b.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::Transparent
  $b.UseVisualStyleBackColor = $false
  # Transparent corners so rounded metal buttons sit cleanly on both dark cards and bare glass.
  $b.BackColor = [System.Drawing.Color]::Transparent
  $b.ForeColor = if ($usePrimary) { $Theme.TextPrimary } else { $Theme.MenuText }
  $b.Font = New-HudFont 'Segoe UI Semibold' ([Math]::Max(8.0, ($Height / 3.6))) ([System.Drawing.FontStyle]::Bold)
  # Keep label on one line — grow width only when requested (default on)
  if (-not $FixedWidth) {
    $padX = [Math]::Max(16, [int]($Height * 0.7))
    $needW = [System.Windows.Forms.TextRenderer]::MeasureText($b.Text, $b.Font, (New-Object System.Drawing.Size(4096, 256)), ([System.Windows.Forms.TextFormatFlags]::SingleLine -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix)).Width + $padX
    if ($needW -gt $b.Width) { $b.Width = $needW }
  }
  $b.Cursor = [System.Windows.Forms.Cursors]::Hand
  $b.Tag = @{
    Theme      = $Theme
    AccentGlow = [bool]$AccentGlow
    Primary    = [bool]$usePrimary
    Hover      = $false
    Payload    = $Payload
  }

  $b.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $tag = $s.Tag
    $th = $null
    $isPrimary = $false
    $isGlow = $false
    $isHover = $false
    $isLocked = $false
    if ($tag -is [hashtable]) {
      $th = $tag.Theme
      $isPrimary = [bool]$tag.Primary
      $isGlow = [bool]$tag.AccentGlow
      $isHover = [bool]$tag.Hover
      $isLocked = [bool]$tag.Locked
    }
    if (-not $th) { $th = Get-HudTheme }
    $r = $s.ClientRectangle
    $rr = New-Object System.Drawing.Rectangle(1, 1, ($r.Width - 3), ($r.Height - 3))
    if ($rr.Width -lt 4 -or $rr.Height -lt 4) { return }
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $rad = [Math]::Min(10, [Math]::Floor($rr.Height / 2))
    $d = $rad * 2
    $path.AddArc($rr.X, $rr.Y, $d, $d, 180, 90)
    $path.AddArc(($rr.Right - $d), $rr.Y, $d, $d, 270, 90)
    $path.AddArc(($rr.Right - $d), ($rr.Bottom - $d), $d, $d, 0, 90)
    $path.AddArc($rr.X, ($rr.Bottom - $d), $d, $d, 90, 90)
    $path.CloseFigure()
    if ((-not $isLocked) -and ($isGlow -or $isHover -or $isPrimary)) {
      $glow = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(140, $th.AccentCyan), 3)
      $g.DrawPath($glow, $path)
      $glow.Dispose()
    }
    $cTop = if ($isLocked) { [System.Drawing.Color]::FromArgb(64, 72, 86) } elseif ($isPrimary) { $th.PrimaryMetalTop } else { $th.MetalTop }
    $cBot = if ($isLocked) { [System.Drawing.Color]::FromArgb(38, 44, 54) } elseif ($isPrimary) { $th.PrimaryMetalBot } else { $th.MetalBot }
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rr, $cTop, $cBot, 90.0)
    $g.FillPath($br, $path)
    $br.Dispose()
    $edgeColor = if ($isLocked) { [System.Drawing.Color]::FromArgb(90, 102, 118) } else { $th.ChromeMid }
    $edge = New-Object System.Drawing.Pen($edgeColor, 1)
    $g.DrawPath($edge, $path)
    $edge.Dispose()
    $sf = New-Object System.Drawing.StringFormat
    $sf.Alignment = [System.Drawing.StringAlignment]::Center
    $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
    $sf.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
    $sf.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter
    $fg = if ($isLocked) { $th.TextMuted } elseif ($isPrimary) { $th.TextPrimary } else { $th.MenuText }
    $tb = New-Object System.Drawing.SolidBrush($fg)
    $g.DrawString($s.Text, $s.Font, $tb, [System.Drawing.RectangleF]$rr, $sf)
    $tb.Dispose(); $sf.Dispose(); $path.Dispose()
  })

  $b.Add_MouseEnter({
    param($s, $e)
    if ($s.Tag -is [hashtable]) { $s.Tag.Hover = $true; $s.Invalidate() }
  })
  $b.Add_MouseLeave({
    param($s, $e)
    if ($s.Tag -is [hashtable]) { $s.Tag.Hover = $false; $s.Invalidate() }
  })
  return $b
}

function Set-HudMetalButtonPayload($Button, $Payload) {
  if (-not $Button) { return }
  if ($Button.Tag -is [hashtable]) {
    $Button.Tag.Payload = $Payload
  } else {
    $Button.Tag = @{ Payload = $Payload; Theme = (Get-HudTheme); Primary = $false; AccentGlow = $false; Hover = $false }
  }
}

function Get-HudMetalButtonPayload($Button) {
  if (-not $Button) { return $null }
  if ($Button.Tag -is [hashtable]) { return $Button.Tag.Payload }
  return $Button.Tag
}

function Get-HudCtrlId($Control) {
  if (-not $Control) { return '' }
  if ($Control.Tag -is [hashtable]) {
    if ($null -ne $Control.Tag.Payload) { return [string]$Control.Tag.Payload }
    if ($null -ne $Control.Tag.InspId) { return [string]$Control.Tag.InspId }
  }
  return [string]$Control.Tag
}

function New-HudEmojiButton {
  param(
    [string]$Emoji,
    [int]$Width,
    [int]$Height,
    $Theme = (Get-HudTheme)
  )
  $b = New-Object System.Windows.Forms.Button
  $b.UseMnemonic = $false
  $b.Text = $Emoji
  $b.Width = $Width
  $b.Height = $Height
  $b.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $b.FlatAppearance.BorderSize = 1
  $b.FlatAppearance.BorderColor = $Theme.BorderHairline
  $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(68, 82, 102)
  $b.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(82, 100, 124)
  $b.BackColor = [System.Drawing.Color]::FromArgb(52, 60, 74)
  $b.ForeColor = $Theme.TextPrimary
  $b.UseVisualStyleBackColor = $false
  $b.Font = New-Object System.Drawing.Font('Segoe UI Emoji', ([Math]::Max(11.0, ($Height / 2.4))))
  $b.Cursor = [System.Windows.Forms.Cursors]::Hand
  return $b
}

function Get-HudInkPlate($Control, [System.Drawing.Color]$Fallback) {
  $p = $null
  try { $p = $Control.Parent } catch { $p = $null }
  while ($null -ne $p) {
    try {
      if ($p.Tag -is [hashtable] -and $p.Tag.IsGlassSurface) {
        return [System.Drawing.Color]::Transparent
      }
      $bg = $p.BackColor
      if ($bg.A -ge 250 -and -not ($p -is [System.Windows.Forms.Form])) { return $bg }
    } catch { }
    try { $p = $p.Parent } catch { $p = $null }
  }
  return $Fallback
}

function Set-HudSolidType {
  param([Parameter(Mandatory)]$Root)
  # Inside opaque cards (New-HudSectionPanel / dark sub-panels), resolve the card's dark plate
  # and use crisp GDI text (UseCompatibleTextRendering = $false).
  # On bare glass surfaces (IsGlassSurface), keep BackColor Transparent (no RGB(26,30,36) patch)
  # and use GDI+ grayscale AA on Labels so ClearType never splits strokes over the gradient.
  $plate = [System.Drawing.Color]::FromArgb(22, 26, 34)
  $sys = [System.Drawing.SystemColors]::Control
  $stack = New-Object System.Collections.Stack
  $stack.Push($Root)
  while ($stack.Count -gt 0) {
    $c = $stack.Pop()
    $isDynamicBoxCell = $false
    try { $isDynamicBoxCell = ([string]$c.Tag -eq 'content') } catch { $isDynamicBoxCell = $false }
    $isType = (-not $isDynamicBoxCell) -and (
      $c -is [System.Windows.Forms.Label] -or
      $c -is [System.Windows.Forms.CheckBox] -or
      $c -is [System.Windows.Forms.RadioButton] -or
      $c -is [System.Windows.Forms.LinkLabel]
    )
    if ($isType) {
      try {
        $resolved = Get-HudInkPlate $c $plate
        if ($resolved.A -eq 0) {
          $c.BackColor = [System.Drawing.Color]::Transparent
          if (($c -is [System.Windows.Forms.Label]) -and -not ($c -is [System.Windows.Forms.LinkLabel])) {
            $c.UseCompatibleTextRendering = $true
          } else {
            $c.UseCompatibleTextRendering = $false
          }
        } else {
          $c.UseCompatibleTextRendering = $false
          $bg = $c.BackColor
          $bare = ($bg.A -lt 250) -or ($bg.ToArgb() -eq $sys.ToArgb())
          if ($bare) { $c.BackColor = $resolved }
        }
      } catch { }
    }
    try {
      foreach ($ch in @($c.Controls)) { if ($null -ne $ch) { $stack.Push($ch) } }
    } catch { }
  }
}

function New-HudLabel {
  param(
    [string]$Text,
    [System.Drawing.Color]$Fore,
    [System.Drawing.Font]$Font,
    [switch]$AutoSize
  )
  $l = New-Object System.Windows.Forms.Label
  $l.UseMnemonic = $false
  $l.Text = $Text
  $l.ForeColor = $Fore
  $l.Font = $Font
  try { $l.UseCompatibleTextRendering = $false } catch { }
  # Start Transparent so Set-HudSolidType resolves either card plate or bare glass cleanly.
  $l.BackColor = [System.Drawing.Color]::Transparent
  if ($AutoSize) { $l.AutoSize = $true }
  return $l
}

function Apply-HudDialogShell {
  param(
    [Parameter(Mandatory)]$Form,
    [Parameter(Mandatory)]$Scale,
    $Theme = (Get-HudTheme)
  )
  $Form.BackColor = $Theme.ChromeLo
  $Form.ForeColor = $Theme.TextPrimary
  $Form.Font = New-HudFont 'Segoe UI' ([float](9 * $Scale))
  Enable-HudDoubleBuffer -Control $Form
}

function New-HudMenuStrip {
  param($Theme = (Get-HudTheme), [float]$Scale = 1.0)
  $menu = New-Object System.Windows.Forms.MenuStrip
  $menu.BackColor = $Theme.MenuBar
  $menu.ForeColor = $Theme.MenuText
  $menu.RenderMode = [System.Windows.Forms.ToolStripRenderMode]::Professional
  $menu.Font = New-HudFont 'Segoe UI Semibold' ([float](9 * $Scale)) ([System.Drawing.FontStyle]::Bold)
  $menu.Padding = New-Object System.Windows.Forms.Padding(([int](8 * $Scale)), ([int](4 * $Scale)), ([int](8 * $Scale)), ([int](4 * $Scale)))
  # CSS .ccc-menu-bar metal gradient
  $menu.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $r = $s.ClientRectangle
    if ($r.Width -lt 2 -or $r.Height -lt 2) { return }
    $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
      $r,
      [System.Drawing.Color]::FromArgb(224, 228, 232),
      [System.Drawing.Color]::FromArgb(155, 160, 166),
      [System.Drawing.Drawing2D.LinearGradientMode]::Vertical
    )
    $g.FillRectangle($br, $r)
    $br.Dispose()
    $penHi = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200, 255, 255, 255), 1)
    $penLo = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 18, 20, 24), 2)
    $g.DrawLine($penHi, 0, 0, $r.Width, 0)
    $g.DrawLine($penLo, 0, ($r.Height - 1), $r.Width, ($r.Height - 1))
    $penHi.Dispose(); $penLo.Dispose()
  })
  return $menu
}

function New-HudTextBox {
  param([int]$Width, $Theme = (Get-HudTheme), [float]$Scale = 1.0)
  $t = New-Object System.Windows.Forms.TextBox
  $t.Width = $Width
  $t.BackColor = $Theme.GlassDeep
  $t.ForeColor = $Theme.TextPrimary
  $t.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
  $t.Font = New-HudFont 'Consolas' ([float](9 * $Scale))
  return $t
}

function Measure-HudWrap {
  param([string]$Text, $Font, [int]$MaxWidth)
  $flags = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::TextBoxControl -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
  $safeW = [Math]::Max(40, [Math]::Min($MaxWidth, 4096))
  $proposed = New-Object System.Drawing.Size($safeW, 8192)
  try {
    $sz = [System.Windows.Forms.TextRenderer]::MeasureText($Text, $Font, $proposed, $flags)
    return [Math]::Max($sz.Height, ([int]($Font.Height + 2)))
  } catch {
    return [Math]::Max(([int]($Font.Height + 2)), ([int](($Text.Split("`n").Count) * ($Font.Height + 2))))
  }
}

function Get-HudEllipsisText {
  param([string]$Text, $Font, [int]$MaxWidth)
  if ([string]::IsNullOrEmpty($Text)) { return '' }
  if ($null -eq $Font) { return $Text }
  if ($MaxWidth -lt 12) { return '…' }
  # Never pass Size(Int32.MaxValue, …) — TextRenderer throws "Parameter is not valid" / "Ungültiger Parameter".
  $probe = New-Object System.Drawing.Size(8192, 256)
  $flags = [System.Windows.Forms.TextFormatFlags]::SingleLine -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix -bor [System.Windows.Forms.TextFormatFlags]::NoPadding
  $measure = {
    param([string]$s)
    try {
      return [System.Windows.Forms.TextRenderer]::MeasureText($s, $Font, $probe, $flags).Width
    } catch {
      try { return [System.Windows.Forms.TextRenderer]::MeasureText($s, $Font).Width }
      catch { return ($s.Length * [Math]::Max(6, [int]$Font.Size)) }
    }
  }
  $needed = & $measure $Text
  if ($needed -le $MaxWidth) { return $Text }
  $lo = 0; $hi = $Text.Length; $best = '…'
  while ($lo -le $hi) {
    $mid = [int](($lo + $hi) / 2)
    $cand = if ($mid -le 0) { '…' } else { $Text.Substring(0, $mid) + '…' }
    $w = & $measure $cand
    if ($w -le $MaxWidth) { $best = $cand; $lo = $mid + 1 } else { $hi = $mid - 1 }
  }
  return $best
}
