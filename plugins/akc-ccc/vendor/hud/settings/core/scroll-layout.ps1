# Copyright (c) 2026 ready-4-it
# Scroll pages + debounced layout (hashtable state — no dynamic Get-Variable -Name).

function Get-HudPageLayoutState {
  param([string]$PageKey)
  if ([string]::IsNullOrWhiteSpace($PageKey)) { return $null }
  if (-not $script:HudPageLayoutState) { $script:HudPageLayoutState = @{} }
  if (-not $script:HudPageLayoutState.ContainsKey($PageKey)) {
    $script:HudPageLayoutState[$PageKey] = [ordered]@{
      LayoutW         = $null
      ScrollMinH      = $null
      ResizeW         = $null
      Force           = $false
      SettleRemaining = 0
    }
  }
  return $script:HudPageLayoutState[$PageKey]
}

function Invoke-HudPageLayoutRequest {
  param([string]$PageKey)
  if ([string]::IsNullOrWhiteSpace($PageKey)) { return }
  $st = Get-HudPageLayoutState $PageKey
  if (-not $st) { return }
  $st.LayoutW = $null
  $st.Force = $true
  $reg = $script:HudScrollPageRegistry[$PageKey]
  if ($reg -and $reg.Timer) {
    $reg.Timer.Stop()
    $reg.Timer.Start()
  }
}

function Invoke-HudPageLayoutRun {
  param([string]$PageKey)
  if ([string]::IsNullOrWhiteSpace($PageKey)) { return }
  $reg = $script:HudScrollPageRegistry[$PageKey]
  if (-not $reg -or -not $reg.LayoutBlock) { return }
  $safeKey = if ($reg.SafeLayoutKey) { [string]$reg.SafeLayoutKey } else { $PageKey }
  Invoke-HudSafeLayout -Key $safeKey -Layout $reg.LayoutBlock
}

function Stop-HudScrollPageLayouts {
  if (-not $script:HudScrollPageRegistry) { return }
  foreach ($pk in @($script:HudScrollPageRegistry.Keys)) {
    $reg = $script:HudScrollPageRegistry[$pk]
    if ($reg -and $reg.Timer) {
      try { $reg.Timer.Stop(); $reg.Timer.Dispose() } catch { }
      $reg.Timer = $null
    }
  }
  $script:HudScrollPageRegistry = @{}
  $script:HelpLayoutTimer = $null
  $script:RequestHelpLayout = $null
  $script:LayoutHelpPage = $null
}

function New-HudScrollPage {
  param(
    [Parameter(Mandatory)]$Parent,
    $Theme = $null,
    [switch]$ClearHostBackground
  )
  if ($ClearHostBackground) {
    $Parent.BackColor = [System.Drawing.Color]::Transparent
  }
  $thLocal = if ($Theme) { $Theme } elseif ($script:HudTheme) { $script:HudTheme } elseif (Get-Command Get-HudTheme -ErrorAction SilentlyContinue) { Get-HudTheme } else { $null }
  $pad = New-Object System.Windows.Forms.Panel
  $pad.Dock = [System.Windows.Forms.DockStyle]::Fill
  $pad.AutoScroll = $true
  $pad.BackColor = [System.Drawing.Color]::FromArgb(0x1a, 0x1c, 0x1e)
  if ($thLocal -and (Get-Command Add-HudGlassPaint -ErrorAction SilentlyContinue)) {
    Add-HudGlassPaint -Control $pad -Theme $thLocal -NoWatermark -Content
  } else {
    Enable-HudDoubleBuffer -Control $pad
  }
  $Parent.Controls.Add($pad)
  return $pad
}

function Register-HudScrollPageLayout {
  param(
    [Parameter(Mandatory)][string]$PageKey,
    [Parameter(Mandatory)]$ScrollPanel,
    [Parameter(Mandatory)]$VisibilityPage,
    [Parameter(Mandatory)][scriptblock]$LayoutBlock,
    [string]$SafeLayoutKey = '',
    [int]$DebounceMs = 60,
    [int]$SettleDebounceMs = 140
  )
  if ([string]::IsNullOrWhiteSpace($PageKey)) {
    throw 'Register-HudScrollPageLayout: PageKey must not be empty.'
  }
  if ([string]::IsNullOrWhiteSpace($SafeLayoutKey)) { $SafeLayoutKey = $PageKey }

  if (-not $script:HudScrollPageRegistry) { $script:HudScrollPageRegistry = @{} }

  $pk = [string]$PageKey
  $debounce = [int]$DebounceMs
  $settleMs = [int]$SettleDebounceMs

  if ($script:HudScrollPageRegistry.ContainsKey($pk)) {
    $old = $script:HudScrollPageRegistry[$pk]
    if ($old.Timer) {
      try { $old.Timer.Stop(); $old.Timer.Dispose() } catch { }
    }
  }

  $script:HudScrollPageRegistry[$pk] = @{
    PageKey        = $pk
    SafeLayoutKey  = [string]$SafeLayoutKey
    LayoutBlock    = $LayoutBlock
    ScrollPanel    = $ScrollPanel
    VisibilityPage = $VisibilityPage
    Timer          = $null
    DebounceMs     = $debounce
    SettleMs       = $settleMs
  }

  $ScrollPanel.Tag = $pk

  $timer = New-Object System.Windows.Forms.Timer
  $timer.Interval = $debounce
  $timer.Tag = $pk
  $script:HudScrollPageRegistry[$pk].Timer = $timer

  $timer.Add_Tick({
    $t = $this
    if ($null -eq $t) { return }
    $pkLocal = [string]$t.Tag
    if ([string]::IsNullOrWhiteSpace($pkLocal)) { return }
    $reg = $script:HudScrollPageRegistry[$pkLocal]
    if (-not $reg) { return }
    $t.Stop()
    Invoke-HudPageLayoutRun -PageKey $pkLocal
    $st = Get-HudPageLayoutState $pkLocal
    if (-not $st) { return }
    if ($st.SettleRemaining -gt 0) {
      $st.SettleRemaining = [int]$st.SettleRemaining - 1
      $st.Force = $true
      $st.LayoutW = $null
      $t.Interval = [int]$reg.SettleMs
      $t.Start()
      $t.Interval = [int]$reg.DebounceMs
    }
  })

  $ScrollPanel.Add_Resize({
    $panel = $this
    if ($null -eq $panel) { return }
    $pkLocal = [string]$panel.Tag
    if ([string]::IsNullOrWhiteSpace($pkLocal)) { return }
    $reg = $script:HudScrollPageRegistry[$pkLocal]
    if (-not $reg -or -not $reg.Timer) { return }
    if ($reg.VisibilityPage -and -not $reg.VisibilityPage.Visible) { return }
    $st = Get-HudPageLayoutState $pkLocal
    if (-not $st) { return }
    # Use outer Width (not ClientSize) — scrollbar show/hide must not retrigger layout loops.
    $cw = [int]$panel.Width
    if ($cw -lt 40) { $cw = [int]$panel.ClientSize.Width }
    if ($null -ne $st.ResizeW -and [Math]::Abs([int]$st.ResizeW - $cw) -lt 8) { return }
    $st.ResizeW = $cw
    $st.LayoutW = $null
    $reg.Timer.Stop()
    $reg.Timer.Start()
  })

  switch ($pk) {
    'help' {
      $script:LayoutHelpPage = { Invoke-HudPageLayoutRun -PageKey 'help' }
      $script:HelpLayoutTimer = $timer
      $script:RequestHelpLayout = { Invoke-HudPageLayoutRequest -PageKey 'help' }
    }
  }

  return @{
    PageKey = $pk
    State   = (Get-HudPageLayoutState $pk)
    Layout  = { Invoke-HudPageLayoutRun -PageKey $pk }.GetNewClosure()
    Request = { Invoke-HudPageLayoutRequest -PageKey $pk }.GetNewClosure()
    Timer   = $timer
  }
}

# Back-compat alias
function Register-HudScrollPageDebouncedLayout {
  param(
    [Parameter(Mandatory)][string]$SafeLayoutKey,
    [Parameter(Mandatory)]$ScrollPanel,
    [Parameter(Mandatory)]$VisibilityPage,
    [Parameter(Mandatory)][scriptblock]$LayoutBlock,
    [int]$DebounceMs = 60,
    [int]$SettleDebounceMs = 140,
    [string]$WidthStateKey = '',
    [string]$ScrollMinHStateKey = '',
    [string]$ResizeWStateKey = '',
    [string]$ForceStateKey = '',
    [string]$SettleStateKey = ''
  )
  return Register-HudScrollPageLayout `
    -PageKey $SafeLayoutKey `
    -ScrollPanel $ScrollPanel `
    -VisibilityPage $VisibilityPage `
    -LayoutBlock $LayoutBlock `
    -SafeLayoutKey $SafeLayoutKey `
    -DebounceMs $DebounceMs `
    -SettleDebounceMs $SettleDebounceMs
}
