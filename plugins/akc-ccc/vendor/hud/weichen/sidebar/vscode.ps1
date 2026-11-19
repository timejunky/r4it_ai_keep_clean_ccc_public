# Copyright (c) 2026 ready-4-it
# VS Code Agents sidebar weiche (0.2.28 Done / Open Files).
# Same rules as src/visual-context/weichen/workspace/vscode-open-files.mjs:
# Done is not identity (pill hides). A selected row far from Open Files must
# not keep the leftover composite-bar project. Lowest selected row wins.

$script:vsCodeOpenFilesRowPx = 80
$script:vsCodeOpenFilesDonePx = 220
$script:vsCodeSidebarWalkPx = 180

function Get-VsCodeStripDecorations([string]$name) {
  $s = ([string]$name).Trim()
  if (-not $s) { return '' }
  if ($s -match '^([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)') { return $matches[1] }
  if ($s -match '(?:^|\s)([A-Za-z0-9_.-]{2,}/[A-Za-z0-9_.-]{2,})(?:\s|$)') { return $matches[1] }
  $s = [regex]::Replace($s, ',\s*updated\b.*$', '', 'IgnoreCase').Trim()
  $s = [regex]::Replace($s, ',\s*State:.*$', '', 'IgnoreCase').Trim()
  $s = [regex]::Replace($s, ',\s*\d+$', '').Trim()
  $s = [regex]::Replace($s, '\s+\+\d+\b.*$', '').Trim()
  $s = [regex]::Replace($s, '\s+[·•].*$', '').Trim()
  $s = [regex]::Replace($s, '\s+\d+\s+(minutes?|mins?|hours?|hrs?|days?|weeks?|mos?|months?|years?|yrs?)\s+ago\s*$', '', 'IgnoreCase').Trim()
  return $s
}

function Test-VsCodeStatusBucket([string]$name) {
  $raw = ([string]$name).Trim()
  if (-not $raw) { return $false }
  if ($raw -match '^(?i)(chats|done|new|archived)$') { return $true }
  $stripped = Get-VsCodeStripDecorations $raw
  return ($stripped -match '^(?i)(chats|done|new|archived)$')
}

function Test-VsCodeRepoSidebarName([string]$name) {
  $raw = ([string]$name).Trim()
  if (-not $raw) { return $false }
  if ($raw -match '^(?i)(chats|done|new|archived)$') { return $false }
  if ($raw -match '^(?i)Open Files:') { return $false }
  $nm = Get-VsCodeStripDecorations $raw
  if (-not $nm) { return $false }
  if ($nm -match '^(?i)(chats|done|new|archived)$') { return $false }
  if ($nm -match '^(?i)(?:updated\s+)?\d+\s+(minutes?|hours?|days?|weeks?|mos?|months?|years?|yrs?)\s+ago$') { return $false }
  if ($nm -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { return $true }
  if ($nm -match '\.[a-z0-9]{1,8}$' -and $nm -notmatch '\.[a-z0-9]+\.[a-z]{2,}$') { return $false }
  return ($nm -match '^[A-Za-z0-9][A-Za-z0-9_.-]*$' -and $nm -match '[_.-]')
}

function Get-VsCodeRepoFromRow([string]$name) {
  if (-not (Test-VsCodeRepoSidebarName $name)) { return '' }
  return (Get-VsCodeStripDecorations $name)
}

function Test-VsCodeSelectionInDone($rows, $selected) {
  if ($null -eq $selected) { return $false }
  $selY = [int]$selected.Y
  $doneY = [int]::MinValue
  $nextBucketY = [int]::MaxValue
  $foundDone = $false
  foreach ($r in @($rows)) {
    $y = [int]$r.Y
    $nm = [string]$r.Name
    if (-not (Test-VsCodeStatusBucket $nm)) { continue }
    $stripped = Get-VsCodeStripDecorations $nm
    if ($stripped -match '^(?i)done$' -and $y -le $selY -and $y -gt $doneY) {
      $doneY = $y
      $foundDone = $true
    }
    if ($y -gt $selY -and $y -lt $nextBucketY) { $nextBucketY = $y }
  }
  if (-not $foundDone) { return $false }
  return ($selY -ge $doneY -and $selY -lt $nextBucketY)
}

function Get-VsCodeOpenFilesHint($openFiles, $selected) {
  $files = @($openFiles)
  $selY = $null
  if ($null -ne $selected) { $selY = [int]$selected.Y }
  if ($null -ne $selY -and $files.Count -gt 0) {
    $best = $null
    $bestD = [int]::MaxValue
    $bestRow = $null
    $bestRowD = [int]::MaxValue
    foreach ($f in $files) {
      if ([string]::IsNullOrWhiteSpace([string]$f.Hint)) { continue }
      $d = [Math]::Abs([int]$f.Y - $selY)
      if ($d -lt $bestD) { $bestD = $d; $best = $f }
      if (-not $f.Composite -and $d -lt $bestRowD) { $bestRowD = $d; $bestRow = $f }
    }
    if ($null -ne $best -and $bestD -le $script:vsCodeOpenFilesRowPx) { return [string]$best.Hint }
    if ($null -ne $bestRow -and $bestRowD -le $script:vsCodeOpenFilesDonePx) { return [string]$bestRow.Hint }
    return ''
  }
  $bar = $files | Where-Object { $_.Composite -and -not [string]::IsNullOrWhiteSpace([string]$_.Hint) } | Select-Object -First 1
  if ($null -ne $bar) { return [string]$bar.Hint }
  for ($i = $files.Count - 1; $i -ge 0; $i--) {
    if (-not [string]::IsNullOrWhiteSpace([string]$files[$i].Hint)) { return [string]$files[$i].Hint }
  }
  return ''
}

function Get-VsCodeSelectedTreeLabel($rows, $selected) {
  if ($null -eq $selected -or [string]::IsNullOrWhiteSpace([string]$selected.Name)) { return '' }
  if (Test-VsCodeSelectionInDone $rows $selected) { return '' }
  $direct = Get-VsCodeRepoFromRow $selected.Name
  if ($direct) { return $direct }
  $selY = [int]$selected.Y
  $above = @($rows) | Where-Object {
    $y = [int]$_.Y
    ($y -le $selY) -and (($selY - $y) -le $script:vsCodeSidebarWalkPx)
  } | Sort-Object { [int]$_.Y } -Descending
  foreach ($r in $above) {
    if (Test-VsCodeStatusBucket $r.Name) { return '' }
    $nm = Get-VsCodeRepoFromRow $r.Name
    if ($nm -and $nm.Contains('/')) { return $nm }
  }
  return ''
}

function Test-VsCodeExplorerRow([string]$cls, [string]$name) {
  if ($cls -match 'explorer|monaco|scm-|debug-') { return $true }
  $nm = ([string]$name).Trim()
  if (-not $nm) { return $false }
  # File rows in the same window also report IsSelected. Dotted workspace names stay.
  if ($nm -match '\\') { return $true }
  if ($nm -match '\.[a-z0-9]{1,8}$' -and $nm -notmatch '\.[a-z0-9]+\.[a-z]{2,}$' -and $nm -notmatch '/') { return $true }
  return $false
}

function Get-VsCodeSidebarLabel($root) {
  if ($null -eq $root) { return '' }
  $openFiles = @()
  $btnCt = [System.Windows.Automation.ControlType]::Button
  $btnCond = New-Object System.Windows.Automation.PropertyCondition(([System.Windows.Automation.AutomationElement]::ControlTypeProperty), $btnCt)
  $btns = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
  foreach ($b in $btns) {
    $nm = [string]$b.Current.Name
    if ($nm -notmatch '^Open Files:\s*(.+)$') { continue }
    $openFiles += @{
      Hint = $matches[1].Trim()
      Y = [int]$b.Current.BoundingRectangle.Y
      Composite = ([string]$b.Current.ClassName -match 'chat-composite-bar')
    }
  }

  # One query for aria-selected. Per-item GetCurrentPattern on every row froze the desktop.
  $ariaSelected = @{}
  try {
    $selProp = [System.Windows.Automation.SelectionItemPattern]::IsSelectedProperty
    $selCond = New-Object System.Windows.Automation.PropertyCondition($selProp, $true)
    $selEls = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $selCond)
    foreach ($el in $selEls) {
      $sn = [string]$el.Current.Name
      $sc = ''
      try { $sc = [string]$el.Current.ClassName } catch { }
      if ([string]::IsNullOrWhiteSpace($sn)) { continue }
      if (Test-VsCodeExplorerRow $sc $sn) { continue }
      $ariaSelected[$sn] = $true
    }
  } catch { }

  $treeCt = [System.Windows.Automation.ControlType]::TreeItem
  $treeCond = New-Object System.Windows.Automation.PropertyCondition(([System.Windows.Automation.AutomationElement]::ControlTypeProperty), $treeCt)
  $items = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $treeCond)
  $rows = @()
  foreach ($it in $items) {
    $nm = [string]$it.Current.Name
    if ([string]::IsNullOrWhiteSpace($nm)) { continue }
    $clsHit = $false
    try { $clsHit = ([string]$it.Current.ClassName -match '\bselected\b') } catch { }
    $rows += @{
      Name = $nm
      Y = [int]$it.Current.BoundingRectangle.Y
      Selected = ($clsHit -or $ariaSelected.ContainsKey($nm))
    }
  }
  # Several rows can stay selected. The lowest (latest click) wins.
  $sel = $rows | Where-Object { $_.Selected } | Sort-Object { [int]$_.Y } -Descending | Select-Object -First 1
  $script:vsCodeInDone = Test-VsCodeSelectionInDone $rows $sel
  # Chat title is live on click. isActive in state.vscdb is only flushed on blur
  # (pill drag). The weiche matches this title to the cached session.
  $script:vsCodeSelectedChat = ''
  if (-not $script:vsCodeInDone -and $null -ne $sel) {
    if (-not (Get-VsCodeRepoFromRow $sel.Name) -and -not (Test-VsCodeStatusBucket $sel.Name)) {
      $script:vsCodeSelectedChat = Get-VsCodeStripDecorations $sel.Name
    }
  }
  if ($script:vsCodeInDone) { return '' }
  if ($null -eq $sel) { return '' }
  $fromFiles = Get-VsCodeOpenFilesHint $openFiles $sel
  if (-not [string]::IsNullOrWhiteSpace($fromFiles)) { return $fromFiles }
  return (Get-VsCodeSelectedTreeLabel $rows $sel)
}
