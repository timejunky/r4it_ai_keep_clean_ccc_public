# Copyright (c) 2026 ready-4-it
# About scroll shell — flat aboutPad (scrollbar); same model as Aktivierung / release 0.2.34.

  $proUrl = if ($script:hudUpgradeUrl) { [string]$script:hudUpgradeUrl } else { 'https://www.ready-4-it.com/akc_ccc' }
  $tierNow = if ($script:hudTier) { [string]$script:hudTier } else { 'none' }
  $editionLabel = switch ($tierNow) {
    'full' { Get-HudT 'about.edition.pro' }
    'trial' { Get-HudT 'about.edition.trial' }
    default { Get-HudT 'about.edition.free' }
  }
  $hostLabel = Get-CccAboutHostLabel
  $hudBuildLabel = Get-CccHudBuildDisplay
  $hudRoot = if ($script:HudScriptRoot) { [string]$script:HudScriptRoot } else { Split-Path $PSScriptRoot -Parent }
  $hudSourceTag = if ([string]$hudRoot -match 'plugins[\\/]local[\\/]ai-keep-clean-ccc') { 'plugin' } else { 'dev' }

  $aboutPad = New-Object System.Windows.Forms.Panel
  $aboutPad.Dock = [System.Windows.Forms.DockStyle]::Fill
  $aboutPad.AutoScroll = $true
  $aboutPad.BackColor = [System.Drawing.Color]::FromArgb(0x1a, 0x1c, 0x1e)
  Add-HudGlassPaint -Control $aboutPad -Theme $th -NoWatermark -Content
  Enable-HudDoubleBuffer -Control $aboutPad
  $ui.pageAbout.Controls.Add($aboutPad)
