# Copyright (c) 2026 ready-4-it
# AI Keep Clean CCC — Home-tip floating form (word-wrap above the pill).
# Job: own the HudTipForm Add-Type, tip show/hide logic, and pointer-on-tip guard.
# Caller: winforms-pill.ps1 (dot-sourced after $form and $script:pillToolTip exist).

function Format-HudTipBlock([string]$text) {
  $words = @([regex]::Split([string]$text, '\s+') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  $lines = New-Object System.Collections.Generic.List[string]
  $cur = ''
  foreach ($w in $words) {
    $next = if ($cur) { "$cur $w" } else { [string]$w }
    if ($cur -and $next.Length -gt 34) {
      [void]$lines.Add($cur)
      $cur = [string]$w
    } else {
      $cur = $next
    }
  }
  if ($cur) { [void]$lines.Add($cur) }
  return ($lines -join "`n")
}

function Ensure-HudHomeTipForm {
  if ($script:homeTipForm -and -not $script:homeTipForm.IsDisposed) { return }
  if (-not ('HudTipForm' -as [type])) {
    Add-Type -ReferencedAssemblies @('System.Windows.Forms.dll', 'System.Drawing.dll') -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public static class HudTipWin {
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
  public static readonly IntPtr HWND_TOPMOST = new IntPtr(-1);
  public const uint SWP_NOACTIVATE = 0x0010;
  public const uint SWP_SHOWWINDOW = 0x0040;
  public static void ShowTop(IntPtr hwnd, int x, int y, int w, int h) {
    SetWindowPos(hwnd, HWND_TOPMOST, x, y, w, h, SWP_NOACTIVATE | SWP_SHOWWINDOW);
  }
}
public class HudTipForm : Form {
  protected override bool ShowWithoutActivation { get { return true; } }
}
'@
  }
  $tip = New-Object HudTipForm
  $tip.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
  $tip.ShowInTaskbar = $false
  $tip.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
  $tip.AutoSize = $false
  $tip.BackColor = [System.Drawing.Color]::FromArgb(22, 26, 34)
  $tip.ForeColor = [System.Drawing.Color]::FromArgb(236, 240, 246)
  $script:homeTipForm = $tip
  $script:homeTipFont = New-Object System.Drawing.Font('Segoe UI', 8.0)
  $tip.add_MouseLeave({ try { Hide-HudPillTipAbove } catch { } })
}

function Test-HudPointerOnHomeTip {
  if (-not $script:pillTipShown) { return $false }
  if (-not $script:homeTipForm -or $script:homeTipForm.IsDisposed) { return $false }
  try { return $script:homeTipForm.Bounds.Contains([System.Windows.Forms.Cursor]::Position) } catch { return $false }
}

function Show-HudPillTipAbove {
  if ([string]::IsNullOrWhiteSpace([string]$script:pillTipText)) { return }
  if (-not $form) { return }
  try { Ensure-HudHomeTipForm } catch { return }
  $text = [string]$script:pillTipText
  $font = $script:homeTipFont
  $flags = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::NoPadding
  $measured = [System.Windows.Forms.TextRenderer]::MeasureText($text, $font, (New-Object System.Drawing.Size 260, 400), $flags)
  $tw = [int]($measured.Width + 16)
  $th = [int]($measured.Height + 12)
  $bmp = New-Object System.Drawing.Bitmap $tw, $th
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  try {
    $g.Clear($script:homeTipForm.BackColor)
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $brush = New-Object System.Drawing.SolidBrush $script:homeTipForm.ForeColor
    try {
      $g.DrawString($text, $font, $brush, (New-Object System.Drawing.RectangleF 8, 6, ([float]($tw - 16)), ([float]($th - 12))))
    } finally { $brush.Dispose() }
  } finally { $g.Dispose() }
  $old = $null
  try { $old = $script:homeTipForm.BackgroundImage } catch { }
  $script:homeTipForm.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::None
  $script:homeTipForm.BackgroundImage = $bmp
  $script:homeTipForm.ClientSize = New-Object System.Drawing.Size $tw, $th
  if ($null -ne $old) { try { $old.Dispose() } catch { } }
  if (-not $script:homeTipForm.Visible) { $script:homeTipForm.Show() }
  $x = $form.Left
  $y = $form.Top - $th - 8
  if ($y -lt 4) { $y = $form.Bottom + 8 }
  try { [HudTipWin]::ShowTop($script:homeTipForm.Handle, $x, $y, $tw, $th) } catch { return }
  try { $script:homeTipForm.Invalidate() } catch { }
  $script:pillTipShown = $true
}

function Hide-HudPillTipAbove {
  param([switch]$Force)
  if (-not $Force) {
    if (-not $script:pillTipShown) { return }
    try {
      $p = $form.PointToClient([System.Windows.Forms.Cursor]::Position)
      if ($form.ClientRectangle.Contains($p)) { return }
    } catch { }
    if (Test-HudPointerOnHomeTip) { return }
  }
  $script:pillTipShown = $false
  try {
    if ($script:homeTipForm -and -not $script:homeTipForm.IsDisposed -and $script:homeTipForm.IsHandleCreated) {
      [CccHudWin]::HideNoActivate($script:homeTipForm.Handle)
    }
  } catch { }
}
