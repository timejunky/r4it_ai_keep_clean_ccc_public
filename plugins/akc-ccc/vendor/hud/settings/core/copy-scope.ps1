# Copyright (c) 2026 ready-4-it
# Copy icon on every HUD page: scope, version, VS version, derivative, project.

function Get-HudCopyLabel([string]$Key, [string]$Fallback) {
  if (Get-Command Get-HudT -ErrorAction SilentlyContinue) {
    $t = Get-HudT $Key
    if ($t -and $t -ne $Key) { return [string]$t }
  }
  return $Fallback
}

function Get-HudHostProductInfo {
  $names = @('Cursor', 'Code', 'Code - Insiders', 'Antigravity')
  $dirs = New-Object System.Collections.Generic.List[string]
  try {
    $procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $names -contains $_.ProcessName })
    foreach ($p in $procs) {
      $exe = ''
      try { $exe = [string]$p.Path } catch { $exe = '' }
      if ([string]::IsNullOrWhiteSpace($exe)) {
        try { $exe = [string]$p.MainModule.FileName } catch { $exe = '' }
      }
      if (-not [string]::IsNullOrWhiteSpace($exe)) {
        [void]$dirs.Add((Split-Path -Parent $exe))
      }
    }
  } catch { }
  if ($env:LOCALAPPDATA) {
    [void]$dirs.Add((Join-Path $env:LOCALAPPDATA 'Programs\cursor'))
    [void]$dirs.Add((Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code'))
    [void]$dirs.Add((Join-Path $env:LOCALAPPDATA 'Programs\Antigravity'))
  }
  foreach ($dir in $dirs) {
    if ([string]::IsNullOrWhiteSpace($dir)) { continue }
    $candidates = @(
      (Join-Path $dir 'resources\app\product.json'),
      (Join-Path $dir 'product.json')
    )
    foreach ($prod in $candidates) {
      if (-not (Test-Path -LiteralPath $prod)) { continue }
      try {
        $j = Get-Content -LiteralPath $prod -Raw -Encoding UTF8 | ConvertFrom-Json
        $ver = [string]$j.version
        $commit = [string]$j.commit
        if ($commit.Length -gt 10) { $commit = $commit.Substring(0, 10) }
        $name = [string]$j.nameLong
        if ([string]::IsNullOrWhiteSpace($name)) { $name = [string]$j.nameShort }
        $quality = [string]$j.quality
        if ([string]::IsNullOrWhiteSpace($quality)) { $quality = 'stable' }
        return [pscustomobject]@{
          Name    = $name
          Version = $ver
          Commit  = $commit
          Quality = $quality
        }
      } catch { }
    }
  }
  return $null
}

function Get-HudScopeCopyText([string]$ScopeId) {
  $id = if ([string]::IsNullOrWhiteSpace($ScopeId)) { 'ccc/hud' } else { $ScopeId.Trim() }
  $ident = $null
  if (Get-Command Get-HudRuntimeIdentity -ErrorAction SilentlyContinue) {
    try { $ident = Get-HudRuntimeIdentity } catch { $ident = $null }
  }
  $version = ''
  if ($ident -and $ident.Version) { $version = [string]$ident.Version }
  if (-not $version -and (Get-Command Get-CccVersion -ErrorAction SilentlyContinue)) {
    try { $version = [string](Get-CccVersion) } catch { }
  }
  if (-not $version) { $version = '0.0.0' }
  $derivative = if ($ident -and $ident.Derivative) { [string]$ident.Derivative } else { '' }
  $project = ''
  try { $project = [string]$script:lastLabelCore } catch { $project = '' }
  $hostId = ''
  try { $hostId = [string]$script:scopeHost } catch { $hostId = '' }
  $hostKey = switch ($hostId) {
    'cursor' { 'pill.scope.cursor' }
    'vscode' { 'pill.scope.vscode' }
    'antigravity' { 'pill.scope.antigravity' }
    default { '' }
  }
  $hostName = if ($hostKey) { Get-HudCopyLabel $hostKey '' } else { '' }
  $scopeLine = $id
  if (-not [string]::IsNullOrWhiteSpace($hostName)) { $scopeLine = "$id  ·  $hostName" }
  $edit = ''
  try { $edit = [string]$script:editScope } catch { $edit = '' }
  if ($edit -eq 'global') { $scopeLine = "$scopeLine  ·  $(Get-HudCopyLabel 'hud.copy.edit.global' 'global')" }
  elseif ($edit -eq 'project') { $scopeLine = "$scopeLine  ·  $(Get-HudCopyLabel 'hud.copy.edit.project' 'project')" }
  $ide = Get-HudHostProductInfo
  $variation = if ($derivative) { $derivative } else { 'unknown' }
  $vsVersion = 'unknown'
  if ($ide) {
    if (-not [string]::IsNullOrWhiteSpace($ide.Name)) {
      $variation = '{0} ({1})' -f $ide.Name, $ide.Quality
    }
    if (-not [string]::IsNullOrWhiteSpace($ide.Version)) {
      $vsVersion = $ide.Version
      if (-not [string]::IsNullOrWhiteSpace($ide.Commit)) { $vsVersion = "$vsVersion ($($ide.Commit))" }
    }
  }
  $lines = @(
    "$(Get-HudCopyLabel 'hud.copy.field.scope' 'Scope'): $scopeLine",
    "$(Get-HudCopyLabel 'hud.copy.field.project' 'Project'): $(if ($project) { $project } else { '—' })",
    "$(Get-HudCopyLabel 'hud.copy.field.version' 'Version'): $version",
    "$(Get-HudCopyLabel 'hud.copy.field.derivative' 'Derivative'): $(if ($derivative) { $derivative } else { '—' })",
    "$(Get-HudCopyLabel 'hud.copy.field.variation' 'VS Code variation'): $variation",
    "$(Get-HudCopyLabel 'hud.copy.field.vsVersion' 'VS Code version'): $vsVersion",
    "$(Get-HudCopyLabel 'hud.copy.field.menu' 'Menu'): $((@(
      (Get-HudCopyLabel 'nav.settings' 'Settings'),
      (Get-HudCopyLabel 'nav.storage' 'Storage'),
      (Get-HudCopyLabel 'nav.activation' 'Activation'),
      (Get-HudCopyLabel 'nav.help' 'Help'),
      (Get-HudCopyLabel 'nav.about' 'About')
    ) -join ' · '))",
    "$(Get-HudCopyLabel 'hud.copy.field.content' 'Content'): $(Get-HudCopyLabel 'help.sketch.content' 'Content')"
  )
  return ($lines -join "`n")
}

function Invoke-HudScopeCopy([string]$ScopeId, $button) {
  $text = Get-HudScopeCopyText $ScopeId
  try { [System.Windows.Forms.Clipboard]::SetText($text) } catch { return }
  if (-not $button) { return }
  $prev = [string]$button.Text
  $button.Text = [char]0xE73E
  $timer = New-Object System.Windows.Forms.Timer
  $timer.Interval = 900
  $timer.Tag = $button
  $script:hudCopyRestore = $prev
  $timer.Add_Tick({
    param($s, $e)
    try { $s.Stop() } catch { }
    try {
      $mark = [char]0xE8C8
      if ($script:hudCopyRestore) { $mark = [string]$script:hudCopyRestore }
      $s.Tag.Text = $mark
    } catch { }
    try { $s.Dispose() } catch { }
  })
  $timer.Start()
}

function New-HudScopeCopyButton([string]$ScopeId, [int]$Side) {
  $tip = 'Copy scope, version, VS version, derivative, project'
  if (Get-Command Get-HudT -ErrorAction SilentlyContinue) {
    $t = Get-HudT 'hud.copy.scope'
    if ($t -and $t -ne 'hud.copy.scope') { $tip = $t }
  }
  $btn = New-Object System.Windows.Forms.Button
  $btn.UseMnemonic = $false
  $btn.Size = New-Object System.Drawing.Size($Side, $Side)
  $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
  $btn.FlatAppearance.BorderSize = 0
  $btn.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(28, 255, 255, 255)
  $btn.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(40, 255, 255, 255)
  $btn.UseVisualStyleBackColor = $false
  $btn.BackColor = [System.Drawing.Color]::FromArgb(24, 28, 36)
  $btn.ForeColor = [System.Drawing.Color]::FromArgb(118, 126, 138)
  $btn.Text = [char]0xE8C8
  try { $btn.Font = New-Object System.Drawing.Font('Segoe MDL2 Assets', ([float](8 * $scale))) } catch {
    $btn.Font = New-Object System.Drawing.Font('Segoe UI', ([float](9 * $scale)))
    $btn.Text = '⧉'
  }
  $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
  $btn.TabStop = $false
  $btn.Tag = $ScopeId
  if (-not $script:hudCopyTip) {
    $script:hudCopyTip = New-Object System.Windows.Forms.ToolTip
    $script:hudCopyTip.ShowAlways = $true
    $script:hudCopyTip.InitialDelay = 350
  }
  try { $script:hudCopyTip.SetToolTip($btn, $tip) } catch { }
  $btn.AccessibleName = $tip
  $btn.Add_Click({
    param($s, $e)
    Invoke-HudScopeCopy ([string]$s.Tag) $s
  })
  return $btn
}

function Update-HudPageCopyButton($page) {
  if (-not $page) { return }
  $btn = $null
  foreach ($c in @($page.Controls)) {
    if ([string]$c.Tag -like 'ccc/hud/*') { $btn = $c; break }
  }
  if (-not $btn) { return }
  $m = 10
  try { if ($scale) { $m = [int](10 * $scale) } } catch { }
  $rightMargin = $m
  $tagId = [string]$btn.Tag
  if ($tagId -eq 'ccc/hud/storage' -or $tagId -eq 'ccc/hud/activation' -or $tagId -eq 'ccc/hud/about') {
    $rightMargin = [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth + [int](6 * $scale)
  }
  try {
    if ($page.BackColor.A -eq 0 -or ($page.Tag -is [hashtable] -and $page.Tag.IsGlassSurface)) {
      $btn.BackColor = [System.Drawing.Color]::Transparent
    } else {
      $btn.BackColor = $page.BackColor
    }
  } catch { }
  $btn.Left = [Math]::Max($m, ($page.ClientSize.Width - $btn.Width - $rightMargin))
  $btn.Top = [Math]::Max($m, ($page.ClientSize.Height - $btn.Height - $m))
  try { $btn.BringToFront() } catch { }
}

function Add-HudScopeCopyChrome {
  if ($ui.btnCopyScope) {
    Update-HudPageCopyButton $ui.pageEinst
    Update-HudPageCopyButton $ui.pageSpeicher
    Update-HudPageCopyButton $ui.pageHilfe
    Update-HudPageCopyButton $ui.pageLizenz
    Update-HudPageCopyButton $ui.pageAbout
    return
  }
  $ui.btnCopyScope = $true

  $pages = @(
    @{ Page = $ui.pageEinst; Id = 'ccc/hud/settings' },
    @{ Page = $ui.pageSpeicher; Id = 'ccc/hud/storage' },
    @{ Page = $ui.pageHilfe; Id = 'ccc/hud/help' },
    @{ Page = $ui.pageLizenz; Id = 'ccc/hud/activation' },
    @{ Page = $ui.pageAbout; Id = 'ccc/hud/about' }
  )
  $pageSide = [Math]::Max(18, [int](20 * $scale))
  foreach ($row in $pages) {
    $page = $row.Page
    if (-not $page) { continue }
    $btn = New-HudScopeCopyButton ([string]$row.Id) $pageSide
    $btn.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    $page.Controls.Add($btn)
    $page.Add_Resize({
      param($s, $e)
      Update-HudPageCopyButton $s
    })
    Update-HudPageCopyButton $page
  }
}
