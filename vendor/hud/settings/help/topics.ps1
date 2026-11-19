# Copyright (c) 2026 ready-4-it
# Help topic panels + nav buttons.

  foreach ($topic in $helpTopics) {
    $navTitle = [string]$topic.title
    $navKey = "help.topic.$($topic.id).nav"
    $navAlt = Get-HudT $navKey
    if ($navAlt -and $navAlt -ne $navKey) { $navTitle = $navAlt }

    $nb = New-Object System.Windows.Forms.Button
    $nb.UseMnemonic = $false
    $nb.Text = $navTitle
    $nb.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $nb.FlatAppearance.BorderSize = 0
    $nb.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(38, 60, 84)
    $nb.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(52, 82, 112)
    $nb.UseVisualStyleBackColor = $false
    $nb.BackColor = [System.Drawing.Color]::Transparent
    $nb.ForeColor = $th.TextPrimary
    $nb.Font = New-HudFont 'Segoe UI Semibold' ([float](9 * $scale))
    $nb.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $nb.Padding = New-Object System.Windows.Forms.Padding($navPadX, ([int](4 * $scale)), ([int](4 * $scale)), ([int](4 * $scale)))
    $nb.Width = $navBtnW
    $flags = [System.Windows.Forms.TextFormatFlags]::WordBreak -bor [System.Windows.Forms.TextFormatFlags]::TextBoxControl -bor [System.Windows.Forms.TextFormatFlags]::NoPrefix
    $innerW = [Math]::Max(40, $navBtnW - (2 * $navPadX) - ([int](8 * $scale)))
    $needH = [System.Windows.Forms.TextRenderer]::MeasureText(
      $navTitle,
      $nb.Font,
      (New-Object System.Drawing.Size($innerW, [int]::MaxValue)),
      $flags
    ).Height + ([int](10 * $scale))
    $nb.Height = [Math]::Max($navMinH, $needH)
    $nb.Location = New-Object System.Drawing.Point(([int](4 * $scale)), $navY)
    $nb.Cursor = [System.Windows.Forms.Cursors]::Hand
    $nb.TabStop = $false
    $nb.Tag = $topic.id
    $nb.Add_MouseEnter({
      param($s, $e)
      $isAct = ([string]$s.Tag -eq [string]$script:HelpTopicId)
      $s.ForeColor = if ($isAct) { [System.Drawing.Color]::White } else { $th.AccentCyan }
    })
    $nb.Add_MouseLeave({
      param($s, $e)
      $isAct = ([string]$s.Tag -eq [string]$script:HelpTopicId)
      $s.ForeColor = if ($isAct) { [System.Drawing.Color]::White } else { $th.TextPrimary }
    })
    $helpNav.Controls.Add($nb)
    $ui.helpTopicButtons[$topic.id] = $nb
    $navY += $nb.Height + $navGap

    $sec = New-HudSectionPanel -X 0 -Y 0 -Width ([int](640 * $scale)) -Height ([int](400 * $scale)) -Theme $th
    $sec.Visible = $false
    $helpBody.Controls.Add($sec)

    $ht = New-HudLabel -Text $topic.title -Fore $th.AccentCyan -Font (New-HudFont 'Segoe UI Semibold' ([float](14 * $scale)) ([System.Drawing.FontStyle]::Bold)) -AutoSize
    $sec.Controls.Add($ht)

    $hb = New-HudLabel -Text $topic.body.Trim() -Fore $th.TextPrimary -Font (New-HudFont 'Segoe UI' ([float](9.5 * $scale)))
    $hb.AutoSize = $false
    $sec.Controls.Add($hb)

    $fig = $null
    if ($topic.id -eq 'overview' -or $topic.id -eq 'nav') {
      $fig = New-Object System.Windows.Forms.Panel
      $fig.Height = [int](96 * $scale)
      $fig.BackColor = [System.Drawing.Color]::FromArgb(28, 34, 44)
      $menuLine = (@(
        (Get-HudT 'nav.settings'),
        (Get-HudT 'nav.storage'),
        (Get-HudT 'nav.activation'),
        (Get-HudT 'nav.help'),
        (Get-HudT 'nav.about')
      ) -join '   ')
      $contentLine = Get-HudT 'help.sketch.content'
      if ($contentLine -eq 'help.sketch.content') { $contentLine = 'Content' }
      $fig.Tag = @{ Menu = $menuLine; Content = $contentLine; Scale = [double]$scale }
      Enable-HudDoubleBuffer -Control $fig
      $fig.Add_Paint({
        param($s, $e)
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
        $r = $s.ClientRectangle
        $sc = 1.0
        $menu = ''
        $content = ''
        if ($s.Tag -is [hashtable]) {
          if ($s.Tag.Scale) { $sc = [double]$s.Tag.Scale }
          $menu = [string]$s.Tag.Menu
          $content = [string]$s.Tag.Content
        }
        $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(90, 209, 232), 2)
        $br = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(50, 90, 209, 232))
        $menuInk = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(240, 244, 248))
        $bodyInk = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(186, 198, 214))
        $font = New-Object System.Drawing.Font('Segoe UI', ([float](8 * $sc)))
        $menuH = [int](22 * $sc)
        $g.DrawRectangle($pen, 8, 8, ($r.Width - 16), ($r.Height - 16))
        $g.FillRectangle($br, 10, 10, ($r.Width - 20), $menuH)
        $g.DrawString($menu, $font, $menuInk, 14, 12)
        $g.DrawString($content, $font, $bodyInk, 14, (18 + $menuH))
        $font.Dispose(); $menuInk.Dispose(); $bodyInk.Dispose(); $pen.Dispose(); $br.Dispose()
      })
      $sec.Controls.Add($fig)
    }

    $copyHost = $null
    if ($topic.id -eq 'hudops') {
      $copyHost = New-Object System.Windows.Forms.Panel
      $copyHost.BackColor = [System.Drawing.Color]::Transparent
      $sec.Controls.Add($copyHost)

      $copyTitle = New-HudLabel -Text (Get-HudT 'help.copy.section') -Fore $th.AccentCyan -Font (New-HudFont 'Segoe UI Semibold' ([float](11 * $scale)) ([System.Drawing.FontStyle]::Bold)) -AutoSize
      $copyHost.Controls.Add($copyTitle)

      $pluginRelUnix = '.cursor/plugins/local/ai-keep-clean-ccc'
      $pluginRelWinCmd = '%USERPROFILE%\.cursor\plugins\local\ai-keep-clean-ccc'
      $pluginRelWinPs = "Join-Path `$HOME '$pluginRelUnix'"
      $shellSpecs = @{
        wincmd = @(
          @{ Id = 'folder'; Value = $pluginRelWinCmd },
          @{ Id = 'cd'; Value = "cd /d `"$pluginRelWinCmd`"" },
          @{ Id = 'start'; Value = 'npm run hud:start' },
          @{ Id = 'stop'; Value = 'npm run hud:stop' },
          @{ Id = 'startOne'; Value = "node `"$pluginRelWinCmd\vendor\hud\hud-start.mjs`"" },
          @{ Id = 'stopOne'; Value = "node `"$pluginRelWinCmd\vendor\hud\hud-stop.mjs`"" }
        )
        winps = @(
          @{ Id = 'folder'; Value = "($pluginRelWinPs)" },
          @{ Id = 'cd'; Value = "Set-Location ($pluginRelWinPs)" },
          @{ Id = 'start'; Value = 'npm run hud:start' },
          @{ Id = 'stop'; Value = 'npm run hud:stop' },
          @{ Id = 'startOne'; Value = "node (Join-Path `$HOME '$pluginRelUnix/vendor/hud/hud-start.mjs')" },
          @{ Id = 'stopOne'; Value = "node (Join-Path `$HOME '$pluginRelUnix/vendor/hud/hud-stop.mjs')" }
        )
        mac = @(
          @{ Id = 'folder'; Value = "~/$pluginRelUnix" },
          @{ Id = 'cd'; Value = "cd ~/$pluginRelUnix" },
          @{ Id = 'start'; Value = 'npm run hud:start' },
          @{ Id = 'stop'; Value = 'npm run hud:stop' },
          @{ Id = 'startOne'; Value = "node ~/$pluginRelUnix/vendor/hud/hud-start.mjs" },
          @{ Id = 'stopOne'; Value = "node ~/$pluginRelUnix/vendor/hud/hud-stop.mjs" }
        )
        linux = @(
          @{ Id = 'folder'; Value = "~/$pluginRelUnix" },
          @{ Id = 'cd'; Value = "cd ~/$pluginRelUnix" },
          @{ Id = 'start'; Value = 'npm run hud:start' },
          @{ Id = 'stop'; Value = 'npm run hud:stop' },
          @{ Id = 'startOne'; Value = "node ~/$pluginRelUnix/vendor/hud/hud-start.mjs" },
          @{ Id = 'stopOne'; Value = "node ~/$pluginRelUnix/vendor/hud/hud-stop.mjs" }
        )
      }

      $tabBar = New-Object System.Windows.Forms.Panel
      $tabBar.Height = [int](32 * $scale)
      $tabBar.BackColor = [System.Drawing.Color]::Transparent
      $copyHost.Controls.Add($tabBar)

      $rowH = [int](34 * $scale)
      $btnCopyW = [int](96 * $scale)
      $labelW = [int](140 * $scale)
      $tabGap = [int](6 * $scale)
      $tabH = [int](28 * $scale)
      $shellOrder = @('wincmd', 'winps', 'mac', 'linux')
      $tabBtns = @{}
      $shellPanels = @{}
      $allRows = @()
      $defaultShell = 'winps'

      foreach ($copyShellKey in $shellOrder) {
        $tabBtn = New-FlatBtn (Get-HudT "help.copy.tab.$copyShellKey") ([int](78 * $scale)) $tabH $bgBtn
        Set-HudMetalButtonPayload $tabBtn $copyShellKey
        $tabBar.Controls.Add($tabBtn)
        $tabBtns[$copyShellKey] = $tabBtn

        $panel = New-Object System.Windows.Forms.Panel
        $panel.BackColor = [System.Drawing.Color]::Transparent
        $panel.Visible = $false
        $copyHost.Controls.Add($panel)

        $copyRows = @()
        $rowY = 0
        $hostNoteLbl = $null
        if ($copyShellKey -eq 'mac' -or $copyShellKey -eq 'linux') {
          $hostNoteLbl = New-HudLabel -Text (Get-HudT 'help.copy.hostNote') -Fore $th.TextMuted -Font (New-HudFont 'Segoe UI' ([float](8.5 * $scale)))
          $hostNoteLbl.AutoSize = $false
          $hostNoteLbl.Location = New-Object System.Drawing.Point(0, 0)
          $hostNoteLbl.Height = [int](52 * $scale)
          $panel.Controls.Add($hostNoteLbl)
          $rowY = $hostNoteLbl.Bottom + ([int](6 * $scale))
        }
        foreach ($spec in @($shellSpecs[$copyShellKey])) {
          $row = New-Object System.Windows.Forms.Panel
          $row.Height = $rowH
          $row.BackColor = [System.Drawing.Color]::Transparent
          $row.Location = New-Object System.Drawing.Point(0, $rowY)
          $panel.Controls.Add($row)

          $lbl = New-HudLabel -Text (Get-HudT "help.copy.$($spec.Id)") -Fore $th.TextPrimary -Font (New-HudFont 'Segoe UI Semibold' ([float](9 * $scale))) -AutoSize
          $lbl.Location = New-Object System.Drawing.Point(0, ([int](8 * $scale)))
          $row.Controls.Add($lbl)

          $prev = New-HudLabel -Text ([string]$spec.Value) -Fore $th.TextMuted -Font (New-HudFont 'Consolas' ([float](8.5 * $scale)))
          $prev.AutoSize = $false
          $prev.AutoEllipsis = $true
          $prev.Location = New-Object System.Drawing.Point($labelW, ([int](8 * $scale)))
          $prev.Height = [int](20 * $scale)
          $row.Controls.Add($prev)

          $btn = New-FlatBtn (Get-HudT 'help.copy.btn') $btnCopyW ([int](28 * $scale)) $bgBtn
          $btn.Tag = [string]$spec.Value
          $btn.Add_Click({
            param($s, $e)
            try {
              [System.Windows.Forms.Clipboard]::SetText([string]$s.Tag)
              $orig = $s.Text
              $s.Text = Get-HudT 'help.copy.copied'
              $tm = New-Object System.Windows.Forms.Timer
              $tm.Interval = 1200
              $tm.Tag = @{ Btn = $s; Text = $orig }
              $tm.Add_Tick({
                param($ts, $te)
                $ts.Stop()
                $pack = $ts.Tag
                if ($pack -and $pack.Btn) { $pack.Btn.Text = [string]$pack.Text }
                $ts.Dispose()
              })
              $tm.Start()
            } catch { }
          })
          $row.Controls.Add($btn)
          $copyRows += @{ Row = $row; Label = $lbl; Preview = $prev; Btn = $btn }
          $rowY += $rowH + ([int](4 * $scale))
        }
        $panel.Height = $rowY
        $shellPanels[$copyShellKey] = @{ Panel = $panel; Rows = $copyRows; HostNote = $hostNoteLbl }
        $allRows += $copyRows
      }

      $script:HelpCopyUi = @{
        ShellPanels = $shellPanels
        TabBtns = $tabBtns
        DefaultShell = $defaultShell
        BgBtn = $bgBtn
        Th = $th
      }
      $script:ShowHelpCopyShell = {
        # Do not name the param $shellId — PowerShell automatic $ShellId is read-only.
        param([string]$copyShellKey)
        $pack = $script:HelpCopyUi
        if (-not $pack) { return }
        if (-not $pack.ShellPanels.ContainsKey($copyShellKey)) { $copyShellKey = [string]$pack.DefaultShell }
        foreach ($sid in @($pack.ShellPanels.Keys)) {
          $pack.ShellPanels[$sid].Panel.Visible = ($sid -eq $copyShellKey)
          $tb = $pack.TabBtns[$sid]
          $on = ($sid -eq $copyShellKey)
          if ($tb.Tag -is [hashtable]) {
            $tb.Tag.AccentGlow = $on
            $tb.Tag.Primary = $on
            $tb.Invalidate()
          }
        }
        $script:HelpCopyActiveShell = $copyShellKey
        if ($ui.pageHilfe.Visible) {
          if ($script:RequestHelpLayout) { & $script:RequestHelpLayout }
          elseif ($script:LayoutHelpPage) { & $script:LayoutHelpPage }
        }
      }

      foreach ($copyShellKey in $shellOrder) {
        $tabBtns[$copyShellKey].Add_Click({
          param($s, $e)
          & $script:ShowHelpCopyShell ([string](Get-HudMetalButtonPayload $s))
        })
      }

      & $script:ShowHelpCopyShell $defaultShell
      $copyHost.Tag = @{
        Title = $copyTitle
        TabBar = $tabBar
        TabBtns = $tabBtns
        ShellOrder = $shellOrder
        ShellPanels = $shellPanels
        Rows = $allRows
        LabelW = $labelW
        BtnW = $btnCopyW
        TabGap = $tabGap
      }
    }

    $ui.helpTopicPanels[$topic.id] = @{ Sec = $sec; Title = $ht; Body = $hb; Fig = $fig; CopyHost = $copyHost }
  }

