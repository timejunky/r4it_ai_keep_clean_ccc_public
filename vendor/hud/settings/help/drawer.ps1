# Copyright (c) 2026 ready-4-it
# One help drawer for every settings page. Short text follows the page.
# The Help tab stays the handbook. Open in Help selects that topic.

$script:hudHelpDrawerOpen = $false
if ([string]::IsNullOrWhiteSpace([string]$script:hudSettingsPage)) {
  $script:hudSettingsPage = 'einst'
}
$script:HudHelpTopicFor = @{
  look         = 'look'
  logo         = 'look'
  storage      = 'storage'
  backup       = 'prefs'
  experiments  = 'storage'
  hygiene      = 'storage'
  activate     = 'activate'
  about        = 'privacy'
}

function Get-HudHelpContextId {
  $page = [string]$script:hudSettingsPage
  if ([string]::IsNullOrWhiteSpace($page)) { $page = 'einst' }
  switch ($page) {
    'hilfe' { return '' }
    'lizenz' { return 'activate' }
    'about' { return 'about' }
    'speicher' {
      switch ([string]$script:storTabKey) {
        'bak' { return 'backup' }
        'exp' { return 'experiments' }
        'ext' { return 'hygiene' }
        default { return 'storage' }
      }
    }
    default {
      if ($ui.iconLogoMode) { return 'logo' }
      return 'look'
    }
  }
}

function Get-HudChromeInk([string]$name) {
  $fallback = switch ($name) {
    'MenuText' { [System.Drawing.Color]::FromArgb(26, 28, 32) }
    'TextMuted' { [System.Drawing.Color]::FromArgb(200, 210, 224) }
    'AccentCyan' { [System.Drawing.Color]::FromArgb(90, 209, 232) }
    default { [System.Drawing.Color]::FromArgb(240, 244, 248) }
  }
  $theme = $script:HudTheme
  if ($null -eq $theme) { return $fallback }
  $c = $theme[$name]
  if ($c -is [System.Drawing.Color]) { return $c }
  return $fallback
}

function Update-HudHelpButtonChrome {
  $btn = $ui.btnPageHelp
  if (-not $btn) { return }
  $onHelp = ([string]$script:hudSettingsPage -eq 'hilfe')
  $btn.Enabled = -not $onHelp
  $open = [bool]$script:hudHelpDrawerOpen -and -not $onHelp
  if ($open) {
    $btn.BackColor = [System.Drawing.Color]::FromArgb(60, 74, 107, 140)
    $btn.ForeColor = [System.Drawing.Color]::White
  } else {
    $btn.BackColor = [System.Drawing.Color]::Transparent
    $btn.ForeColor = if ($onHelp) { Get-HudChromeInk 'TextMuted' } else { Get-HudChromeInk 'MenuText' }
  }
  try { $btn.Invalidate() } catch { }
}

function Show-HudHelpDrawerContent {
  $scroll = $ui.pnlHelpDrawer
  if (-not $scroll) { return }
  $id = Get-HudHelpContextId
  if ([string]::IsNullOrWhiteSpace($id)) { $id = 'look' }
  $script:hudHelpContextId = $id
  $title = Get-HudT "help.drawer.$id.title"
  $body = Get-HudT "help.drawer.$id.body"
  if ($ui.lblHelpDrawerTitle) { $ui.lblHelpDrawerTitle.Text = $title }
  $scroll.Controls.Clear()
  $innerW = [Math]::Max([int](180 * $scale), $ui.helpDrawer.ClientSize.Width - [int](36 * $scale))
  if ($innerW -lt [int](180 * $scale)) { $innerW = [int](300 * $scale) }
  $font = New-HudFont 'Segoe UI' ([float](9.5 * $scale))
  $lbl = New-Object System.Windows.Forms.Label
  $lbl.UseMnemonic = $false
  $lbl.Text = $body
  $lbl.ForeColor = (Get-HudChromeInk 'TextPrimary')
  $lbl.Font = $font
  $lbl.BackColor = [System.Drawing.Color]::Transparent
  $lbl.AutoSize = $false
  $lbl.Width = $innerW
  try { $lbl.UseCompatibleTextRendering = $false } catch { }
  $fmt = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::TextBoxControl -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
  $sz = [System.Windows.Forms.TextRenderer]::MeasureText($body, $font, (New-Object System.Drawing.Size($innerW, [int]::MaxValue)), $fmt)
  $lbl.Height = [Math]::Max([int](48 * $scale), [int]($sz.Height + (16 * $scale)))
  $lbl.Location = New-Object System.Drawing.Point(0, 0)
  $scroll.Controls.Add($lbl)
  $scroll.AutoScrollMinSize = New-Object System.Drawing.Size(0, ($lbl.Bottom + [int](12 * $scale)))
  if ($ui.btnHelpDrawerTopic) {
    $topic = [string]$script:HudHelpTopicFor[$id]
    $ui.btnHelpDrawerTopic.Tag = $topic
    $ui.btnHelpDrawerTopic.Enabled = -not [string]::IsNullOrWhiteSpace($topic)
  }
}

function Set-HudHelpDrawerOpen([bool]$open) {
  $drawer = $ui.helpDrawer
  if (-not $drawer) { return }
  if ($open -and ([string]$script:hudSettingsPage -eq 'hilfe')) { $open = $false }
  $script:hudHelpDrawerOpen = $open
  if ($open) {
    $drawer.Visible = $true
    $drawer.Width = [int](340 * $scale)
    Show-HudHelpDrawerContent
  } else {
    $drawer.Width = 0
    $drawer.Visible = $false
  }
  Update-HudHelpButtonChrome
  try { $pages.PerformLayout() } catch { }
}

function Sync-HudHelpDrawer {
  $onHelp = ([string]$script:hudSettingsPage -eq 'hilfe')
  if ($onHelp -and $script:hudHelpDrawerOpen) {
    Set-HudHelpDrawerOpen $false
    return
  }
  if ($script:hudHelpDrawerOpen) { Show-HudHelpDrawerContent }
  Update-HudHelpButtonChrome
}

$ui.btnPageHelp = New-Object System.Windows.Forms.Button
$ui.btnPageHelp.UseMnemonic = $false
$ui.btnPageHelp.Text = Get-HudT 'help.drawer.toggle'
$ui.btnPageHelp.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$ui.btnPageHelp.FlatAppearance.BorderSize = 0
$ui.btnPageHelp.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(40, 0, 0, 0)
$ui.btnPageHelp.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(60, 0, 0, 0)
$ui.btnPageHelp.UseVisualStyleBackColor = $false
$ui.btnPageHelp.BackColor = [System.Drawing.Color]::Transparent
$ui.btnPageHelp.ForeColor = (Get-HudChromeInk 'MenuText')
$ui.btnPageHelp.Font = New-HudFont 'Segoe UI Semibold' ([float](9 * $scale)) ([System.Drawing.FontStyle]::Bold)
$ui.btnPageHelp.Height = [Math]::Max(28, ($menuBand.ClientSize.Height - [int](12 * $scale)))
if ($ui.btnPageHelp.Height -lt 24) { $ui.btnPageHelp.Height = [int](28 * $scale) }
$helpTw = [System.Windows.Forms.TextRenderer]::MeasureText($ui.btnPageHelp.Text, $ui.btnPageHelp.Font).Width
$ui.btnPageHelp.Width = [Math]::Max(([int](72 * $scale)), ($helpTw + [int](22 * $scale)))
$ui.btnPageHelp.Cursor = [System.Windows.Forms.Cursors]::Hand
$ui.btnPageHelp.TabStop = $false
$ui.btnPageHelp.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$tip = New-Object System.Windows.Forms.ToolTip
$tip.SetToolTip($ui.btnPageHelp, (Get-HudT 'help.drawer.tip'))
$menuBand.Controls.Add($ui.btnPageHelp)
$ui.btnPageHelp.Add_Click({
  if ([string]$script:hudSettingsPage -eq 'hilfe') { return }
  Set-HudHelpDrawerOpen (-not [bool]$script:hudHelpDrawerOpen)
})

$prevMenuLang = $script:LayoutMenuLang
$script:LayoutMenuLang = {
  if ($prevMenuLang) { & $prevMenuLang }
  if (-not $ui.btnPageHelp -or -not $ui.cmbLang) { return }
  $gap = [int](8 * $scale)
  $ui.btnPageHelp.Top = [Math]::Max(0, [int](($menuBand.ClientSize.Height - $ui.btnPageHelp.Height) / 2))
  $ui.btnPageHelp.Left = [Math]::Max([int](8 * $scale), ($ui.cmbLang.Left - $ui.btnPageHelp.Width - $gap))
  $ui.btnPageHelp.BringToFront()
  $ui.cmbLang.BringToFront()
}
if ($script:LayoutMenuLang) { & $script:LayoutMenuLang }

$ui.helpDrawer = New-Object System.Windows.Forms.Panel
$ui.helpDrawer.Dock = [System.Windows.Forms.DockStyle]::Right
$ui.helpDrawer.Width = 0
$ui.helpDrawer.Visible = $false
$ui.helpDrawer.BackColor = [System.Drawing.Color]::FromArgb(0x1a, 0x1c, 0x1e)
$ui.helpDrawer.Padding = New-Object System.Windows.Forms.Padding(([int](12 * $scale)))
$pages.Controls.Add($ui.helpDrawer)
foreach ($p in @($ui.pageEinst, $ui.pageSpeicher, $ui.pageHilfe, $ui.pageLizenz, $ui.pageAbout)) {
  if ($p) { try { $p.BringToFront() } catch { } }
}

$helpDrawTop = New-Object System.Windows.Forms.Panel
$helpDrawTop.Dock = [System.Windows.Forms.DockStyle]::Top
$helpDrawTop.Height = [int](36 * $scale)
$helpDrawTop.BackColor = [System.Drawing.Color]::Transparent
$ui.helpDrawer.Controls.Add($helpDrawTop)

$ui.lblHelpDrawerTitle = New-HudLabel -Text '' -Fore $th.AccentCyan -Font (New-HudFont 'Segoe UI Semibold' ([float](11 * $scale)) ([System.Drawing.FontStyle]::Bold)) -AutoSize
$ui.lblHelpDrawerTitle.Location = New-Object System.Drawing.Point(0, [int](4 * $scale))
$helpDrawTop.Controls.Add($ui.lblHelpDrawerTitle)

$ui.btnHelpDrawerClose = New-FlatBtn (Get-HudT 'help.drawer.close') ([int](72 * $scale)) ([int](24 * $scale)) $bgBtn
$ui.btnHelpDrawerClose.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$ui.btnHelpDrawerClose.Location = New-Object System.Drawing.Point(([int](240 * $scale)), 0)
$helpDrawTop.Controls.Add($ui.btnHelpDrawerClose)
$helpDrawTop.Add_Resize({
  if (-not $ui.btnHelpDrawerClose) { return }
  $ui.btnHelpDrawerClose.Left = [Math]::Max(0, ($helpDrawTop.ClientSize.Width - $ui.btnHelpDrawerClose.Width))
})
$ui.btnHelpDrawerClose.Add_Click({ Set-HudHelpDrawerOpen $false })

$helpDrawFoot = New-Object System.Windows.Forms.Panel
$helpDrawFoot.Dock = [System.Windows.Forms.DockStyle]::Bottom
$helpDrawFoot.Height = [int](40 * $scale)
$helpDrawFoot.BackColor = [System.Drawing.Color]::Transparent
$ui.helpDrawer.Controls.Add($helpDrawFoot)

$ui.btnHelpDrawerTopic = New-FlatBtn (Get-HudT 'help.drawer.openTopic') ([int](160 * $scale)) ([int](26 * $scale)) $bgBtn
$ui.btnHelpDrawerTopic.Location = New-Object System.Drawing.Point(0, [int](6 * $scale))
$helpDrawFoot.Controls.Add($ui.btnHelpDrawerTopic)
$ui.btnHelpDrawerTopic.Add_Click({
  param($s, $e)
  $topic = [string]$s.Tag
  if ([string]::IsNullOrWhiteSpace($topic)) { return }
  Set-HudHelpDrawerOpen $false
  Show-Page 'hilfe'
  if (Get-Command Show-HelpTopic -ErrorAction SilentlyContinue) { Show-HelpTopic $topic }
})

$ui.pnlHelpDrawer = New-Object System.Windows.Forms.Panel
$ui.pnlHelpDrawer.Dock = [System.Windows.Forms.DockStyle]::Fill
$ui.pnlHelpDrawer.AutoScroll = $true
$ui.pnlHelpDrawer.BackColor = [System.Drawing.Color]::FromArgb(0x1a, 0x1c, 0x1e)
$ui.helpDrawer.Controls.Add($ui.pnlHelpDrawer)
$ui.pnlHelpDrawer.BringToFront()

Update-HudHelpButtonChrome
