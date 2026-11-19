# Copyright (c) 2026 ready-4-it
# Antigravity navigation point: the project name in
# "Chat - Project - Antigravity". Same role as a Cursor project name.
# A truncated window title is not that name.

$script:agNavAt = [int64]0
$script:agNavName = ''

function Get-AntigravityProjectFromTitle([string]$title) {
  $t = [string]$title
  if ([string]::IsNullOrWhiteSpace($t)) { return '' }
  $t = $t.Trim()
  if ($t -match '^(Antigravity|Antigravity IDE)$') { return '' }
  $t = [regex]::Replace($t, '\s+-\s+Antigravity(\s+IDE)?\s*$', '')
  if ([string]::IsNullOrWhiteSpace($t)) { return '' }
  $nav = ''
  if ($t.Contains('/')) {
    $nav = ($t -split '\s*/\s*', 2)[0].Trim()
  } else {
    $parts = [regex]::Split($t, '\s+-\s+') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($parts.Count -ge 2) { $nav = [string]$parts[$parts.Count - 1] }
  }
  if ([string]::IsNullOrWhiteSpace($nav)) { return '' }
  if ($nav -match '[…]|\.\.\.\s*$') { return '' }
  return $nav.Trim()
}

function Get-AntigravityNavPoint($root) {
  $now = [Environment]::TickCount64
  if ($script:agNavAt -gt 0 -and ($now - $script:agNavAt) -lt 1500) {
    return [string]$script:agNavName
  }
  $script:agNavAt = $now
  if ($null -eq $root) { return [string]$script:agNavName }
  $all = $null
  try {
    $all = $root.FindAll(
      [System.Windows.Automation.TreeScope]::Descendants,
      [System.Windows.Automation.Condition]::TrueCondition
    )
  } catch {
    return [string]$script:agNavName
  }
  foreach ($el in $all) {
    $name = ''
    try { $name = [string]$el.Current.Name } catch { continue }
    if ($name -notmatch '\s-\sAntigravity(\sIDE)?$') { continue }
    $nav = Get-AntigravityProjectFromTitle $name
    if ($nav) {
      $script:agNavName = $nav
      return $nav
    }
  }
  return [string]$script:agNavName
}
