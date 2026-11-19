# Copyright (c) 2026 ready-4-it
# Help tab chrome: root, nav rail, scroll body.

  # ========== HILFE ==========
  $helpRoot = New-Object System.Windows.Forms.Panel
  $helpRoot.Dock = [System.Windows.Forms.DockStyle]::Fill
  $helpRoot.BackColor = [System.Drawing.Color]::FromArgb(0x1a, 0x1c, 0x1e)
  $helpRoot.Padding = New-Object System.Windows.Forms.Padding(([int](16 * $scale)))
  Add-HudGlassPaint -Control $helpRoot -Theme $th -NoWatermark -Content
  $ui.pageHilfe.Controls.Add($helpRoot)

  $helpNav = New-Object System.Windows.Forms.Panel
  $helpNav.Dock = [System.Windows.Forms.DockStyle]::Left
  $helpNav.Width = [int](200 * $scale)
  $helpNav.BackColor = [System.Drawing.Color]::Transparent
  $helpNav.Padding = New-Object System.Windows.Forms.Padding(([int](10 * $scale)))
  $helpNav.AutoScroll = $true
  Enable-HudDoubleBuffer -Control $helpNav
  # Soft edge only — same glass as body (no flat sidebar slab)
  $helpNav.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $x = $s.ClientSize.Width - 1
    if ($x -lt 1) { return }
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(55, 90, 209, 232), 1)
    $g.DrawLine($pen, $x, 8, $x, ($s.ClientSize.Height - 8))
    $pen.Dispose()
  })
  $helpRoot.Controls.Add($helpNav)

  $helpBodyHost = New-Object System.Windows.Forms.Panel
  $helpBodyHost.Dock = [System.Windows.Forms.DockStyle]::Fill
  $helpBodyHost.BackColor = [System.Drawing.Color]::Transparent
  $helpBodyHost.Padding = New-Object System.Windows.Forms.Padding(([int](12 * $scale)), 0, 0, 0)
  $helpRoot.Controls.Add($helpBodyHost)
  $helpBodyHost.BringToFront()

  $helpBody = New-HudScrollPage -Parent $helpBodyHost

  $lblHelpNav = New-HudLabel -Text (Get-HudT 'help.nav') -Fore $th.AccentCyan -Font (New-HudFont 'Segoe UI Semibold' ([float](11 * $scale)) ([System.Drawing.FontStyle]::Bold)) -AutoSize
  $lblHelpNav.Location = New-Object System.Drawing.Point(([int](8 * $scale)), ([int](8 * $scale)))
  $helpNav.Controls.Add($lblHelpNav)

  $helpTopicIds = @('overview', 'start', 'nav', 'scope', 'look', 'storage', 'activate', 'prefs', 'hudops', 'privacy')
  $helpTopics = @()
  foreach ($hid in $helpTopicIds) {
    $h = Invoke-HudTwigHelp $hid
    $helpTopics += @{ id = $hid; title = [string]$h.title; body = [string]$h.body }
  }

  $ui.helpTopicButtons = @{}
  $ui.helpTopicPanels = @{}
  $navY = [int](36 * $scale)
  $navBtnW = [int](176 * $scale)
  $navPadX = [int](8 * $scale)
  $navMinH = [int](32 * $scale)
  $navGap = [int](6 * $scale)
