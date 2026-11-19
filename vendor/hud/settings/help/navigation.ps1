# Copyright (c) 2026 ready-4-it
# Help topic switching + debounced layout.

function Show-HelpTopic([string]$id) {
  if (-not $ui.helpTopicPanels.ContainsKey($id)) { $id = 'overview' }
  foreach ($k in @($ui.helpTopicPanels.Keys)) {
    $ui.helpTopicPanels[$k].Sec.Visible = ($k -eq $id)
  }
  foreach ($k in @($ui.helpTopicButtons.Keys)) {
    $b = $ui.helpTopicButtons[$k]
    $on = ($k -eq $id)
    $b.BackColor = if ($on) { [System.Drawing.Color]::FromArgb(46, 76, 108) } else { [System.Drawing.Color]::Transparent }
    $b.ForeColor = if ($on) { [System.Drawing.Color]::White } else { $th.TextPrimary }
  }
  $script:HelpTopicId = $id
  $helpSt = Get-HudPageLayoutState 'help'
  if ($helpSt) { $helpSt.LayoutW = $null }
  if ($ui.pageHilfe.Visible) {
    if ($script:RequestHelpLayout) { & $script:RequestHelpLayout }
    elseif ($script:LayoutHelpPage) { & $script:LayoutHelpPage }
  }
}

foreach ($topic in $helpTopics) {
  $ui.helpTopicButtons[$topic.id].Add_Click({
    param($s, $e)
    Show-HelpTopic ([string]$s.Tag)
  })
}

$helpLayoutBlock = {
  if (-not $ui.pageHilfe.Visible) { return }
  $helpSt = Get-HudPageLayoutState 'help'
  $pad = [int](22 * $scale)
  $sb = [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth
  $bw = [Math]::Max(([int](420 * $scale)), ($helpBody.ClientSize.Width - ([int](24 * $scale)) - $sb))
  if ($null -ne $helpSt.LayoutW -and [Math]::Abs([int]$helpSt.LayoutW - $bw) -lt 12) { return }
  $helpSt.LayoutW = $bw
  foreach ($k in @($ui.helpTopicPanels.Keys)) {
    $pack = $ui.helpTopicPanels[$k]
    $sec = $pack.Sec
    $sec.Left = [int](8 * $scale)
    $sec.Width = $bw
    $sec.Top = [int](8 * $scale)
    $pack.Title.Location = New-Object System.Drawing.Point($pad, $pad)
    $y = $pack.Title.Bottom + ([int](12 * $scale))
    if ($pack.Fig) {
      $pack.Fig.Location = New-Object System.Drawing.Point($pad, $y)
      $pack.Fig.Width = $bw - (2 * $pad)
      $y = $pack.Fig.Bottom + ([int](14 * $scale))
    }
    $innerW = $bw - (2 * $pad)
    $pack.Body.Location = New-Object System.Drawing.Point($pad, $y)
    $pack.Body.Size = New-Object System.Drawing.Size($innerW, (Measure-HudWrap -Text $pack.Body.Text -Font $pack.Body.Font -MaxWidth $innerW))
    $bottom = $pack.Body.Bottom
    if ($pack.CopyHost) {
      $ch = $pack.CopyHost
      $meta = $ch.Tag
      $ch.Location = New-Object System.Drawing.Point($pad, ($pack.Body.Bottom + ([int](16 * $scale))))
      $ch.Width = $innerW
      $yCopy = 0
      if ($meta -and $meta.Title) {
        $meta.Title.Location = New-Object System.Drawing.Point(0, 0)
        $yCopy = $meta.Title.Bottom + ([int](8 * $scale))
      }
      if ($meta -and $meta.TabBar) {
        $meta.TabBar.Location = New-Object System.Drawing.Point(0, $yCopy)
        $meta.TabBar.Width = $innerW
        $tx = 0
        $tabGap = if ($meta.TabGap) { [int]$meta.TabGap } else { [int](6 * $scale) }
        foreach ($sid in @($meta.ShellOrder)) {
          $tb = $meta.TabBtns[$sid]
          if (-not $tb) { continue }
          $tb.Location = New-Object System.Drawing.Point($tx, 0)
          $tx = $tb.Right + $tabGap
        }
        $yCopy = $meta.TabBar.Bottom + ([int](8 * $scale))
      }
      $gap = [int](8 * $scale)
      $btnW = if ($meta -and $meta.BtnW) { [int]$meta.BtnW } else { [int](96 * $scale) }
      $labelW = if ($meta -and $meta.LabelW) { [int]$meta.LabelW } else { [int](140 * $scale) }
      $prevW = [Math]::Max(40, $innerW - $labelW - $btnW - $gap)
      $activeShell = if ($script:HelpCopyActiveShell) { [string]$script:HelpCopyActiveShell } else { 'winps' }
      $activeH = 0
      if ($meta -and $meta.ShellPanels) {
        foreach ($sid in @($meta.ShellPanels.Keys)) {
          $sp = $meta.ShellPanels[$sid]
          $sp.Panel.Location = New-Object System.Drawing.Point(0, $yCopy)
          $sp.Panel.Width = $innerW
          if ($sp.HostNote) { $sp.HostNote.Width = $innerW }
          foreach ($cr in @($sp.Rows)) {
            $cr.Row.Width = $innerW
            $cr.Preview.Width = $prevW
            $cr.Btn.Location = New-Object System.Drawing.Point(($innerW - $btnW), ([int](2 * $scale)))
          }
          if ($sid -eq $activeShell) { $activeH = $sp.Panel.Height }
        }
      } elseif ($meta -and $meta.Rows) {
        foreach ($cr in @($meta.Rows)) {
          $cr.Row.Width = $innerW
          $cr.Preview.Width = $prevW
          $cr.Btn.Location = New-Object System.Drawing.Point(($innerW - $btnW), ([int](2 * $scale)))
        }
      }
      $ch.Height = $yCopy + [Math]::Max(0, [int]$activeH)
      $bottom = $ch.Bottom
    }
    $sec.Height = $bottom + $pad
  }
  $active = if ($script:HelpTopicId) { [string]$script:HelpTopicId } else { 'overview' }
  if ($ui.helpTopicPanels.ContainsKey($active)) {
    $h = $ui.helpTopicPanels[$active].Sec.Bottom + ([int](16 * $scale))
    $needHScroll = ($helpBody.ClientSize.Height -gt 20) -and ($h -gt $helpBody.ClientSize.Height) -and (-not $helpBody.VerticalScroll.Visible)
    if ($null -eq $helpSt.ScrollMinH -or [Math]::Abs([int]$helpSt.ScrollMinH - $h) -gt 2 -or $needHScroll) {
      $helpSt.ScrollMinH = $h
      $helpBody.AutoScroll = $true
      $helpBody.AutoScrollMinSize = New-Object System.Drawing.Size(0, $h)
      $helpBody.PerformLayout()
    }
  }
}

Register-HudScrollPageLayout -PageKey 'help' -ScrollPanel $helpBody -VisibilityPage $ui.pageHilfe -LayoutBlock $helpLayoutBlock | Out-Null
Show-HelpTopic 'overview'
