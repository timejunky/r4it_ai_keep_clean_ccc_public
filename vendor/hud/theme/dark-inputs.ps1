# Copyright (c) 2026 ready-4-it
# Dark input controls (NumericUpDown / TextBox) — one job: consistent Gemini dark inputs without white WinForms fields.
# Dot-sourced from winforms-theme.ps1.

function Set-HudDarkNumericStyle {
  param(
    [Parameter(Mandatory)]$Control,
    $Theme = (Get-HudTheme)
  )
  $bgInput = [System.Drawing.Color]::FromArgb(28, 34, 44)
  $fgInput = [System.Drawing.Color]::FromArgb(240, 244, 250)
  $Control.BackColor = $bgInput
  $Control.ForeColor = $fgInput
  $Control.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
  $Control.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Right

  foreach ($ch in @($Control.Controls)) {
    if ($null -eq $ch) { continue }
    $typeName = $ch.GetType().Name
    if ($typeName -eq 'UpDownEdit') {
      $ch.BackColor = $bgInput
      $ch.ForeColor = $fgInput
    } elseif ($typeName -eq 'UpDownButtons') {
      $ch.BackColor = [System.Drawing.Color]::FromArgb(36, 44, 56)
      $ch.ForeColor = $fgInput
      if (-not ($ch.Tag -is [hashtable] -and $ch.Tag.DarkSpinnerWired)) {
        $ch.Tag = @{ DarkSpinnerWired = $true; Theme = $Theme }
        $ch.Add_Paint({
          param($s, $e)
          $r = $s.ClientRectangle
          if ($r.Width -lt 4 -or $r.Height -lt 6) { return }
          $th = if ($s.Tag -is [hashtable] -and $s.Tag.Theme) { $s.Tag.Theme } else { Get-HudTheme }
          $g = $e.Graphics
          $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
          $brBg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(36, 44, 56))
          $g.FillRectangle($brBg, $r)
          $brBg.Dispose()

          $midY = [int]($r.Height / 2)
          $penLine = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120, $th.BorderHairline), 1)
          $g.DrawLine($penLine, 0, 0, 0, $r.Height)
          $g.DrawLine($penLine, 0, $midY, $r.Width, $midY)
          $penLine.Dispose()

          $cx = [float]($r.Width / 2.0)
          $aw = [Math]::Max(2.5, [Math]::Min(4.0, ($r.Width * 0.24)))
          $ah = [Math]::Max(2.0, [Math]::Min(3.2, ($r.Height * 0.12)))
          $upCy = [float]($midY / 2.0)
          $dnCy = [float]($midY + (($r.Height - $midY) / 2.0))

          $brArrow = New-Object System.Drawing.SolidBrush($th.AccentCyan)
          $upPts = [System.Drawing.PointF[]]@(
            (New-Object System.Drawing.PointF($cx, ($upCy - $ah))),
            (New-Object System.Drawing.PointF(($cx - $aw), ($upCy + $ah))),
            (New-Object System.Drawing.PointF(($cx + $aw), ($upCy + $ah)))
          )
          $dnPts = [System.Drawing.PointF[]]@(
            (New-Object System.Drawing.PointF($cx, ($dnCy + $ah))),
            (New-Object System.Drawing.PointF(($cx - $aw), ($dnCy - $ah))),
            (New-Object System.Drawing.PointF(($cx + $aw), ($dnCy - $ah)))
          )
          $g.FillPolygon($brArrow, $upPts)
          $g.FillPolygon($brArrow, $dnPts)
          $brArrow.Dispose()
        })
      }
    }
  }
}

function New-HudNumericUpDown {
  param(
    [decimal]$Minimum = 0,
    [decimal]$Maximum = 100,
    [decimal]$Increment = 1,
    [int]$Width = 100,
    [int]$Height = 26,
    [float]$Scale = 1.0,
    $Theme = (Get-HudTheme)
  )
  $n = New-Object System.Windows.Forms.NumericUpDown
  $n.Minimum = $Minimum
  $n.Maximum = $Maximum
  $n.Increment = $Increment
  $n.Width = [Math]::Max(64, $Width)
  $n.Height = $Height
  $n.Font = New-HudFont 'Segoe UI' ([float](9 * $Scale))
  Set-HudDarkNumericStyle -Control $n -Theme $Theme
  return $n
}

function Set-HudDarkTextBoxStyle {
  param([Parameter(Mandatory)]$Control)
  $Control.BackColor = [System.Drawing.Color]::FromArgb(28, 34, 44)
  $Control.ForeColor = [System.Drawing.Color]::FromArgb(240, 244, 250)
  $Control.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
}

function New-HudMultilineTextBox {
  param(
    [int]$Width = 400,
    [int]$Height = 88,
    [float]$Scale = 1.0
  )
  $t = New-Object System.Windows.Forms.TextBox
  $t.Multiline = $true
  $t.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
  $t.AcceptsReturn = $true
  $t.Width = $Width
  $t.Height = $Height
  $t.Font = New-HudFont 'Consolas' ([float](9 * $Scale))
  Set-HudDarkTextBoxStyle -Control $t
  return $t
}
