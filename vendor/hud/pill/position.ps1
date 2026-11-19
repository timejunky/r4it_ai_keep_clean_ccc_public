# Copyright (c) 2026 ready-4-it
# AI Keep Clean CCC — Pill position: per-host offset save/load, offset validation.
# Job: own Load-Pos / Save-Pos / Test-HudSavedOffset.
# Caller: winforms-pill.ps1 (dot-sourced after $posPath / $form / $pad are defined).

function Test-HudSavedOffset([int]$offRight, [int]$offBottom) {
  # Corrupt or negative values are not an offset. A large value stays for Clamp-Offsets.
  return ($offRight -ge 0 -and $offBottom -ge 0 -and $offRight -le 1000000 -and $offBottom -le 1000000)
}

function Load-Pos {
  if (-not (Test-Path -LiteralPath $posPath)) { return }
  try {
    $p = (Get-Content -LiteralPath $posPath -Raw) | ConvertFrom-Json
    $h = if ($script:scopeHost) { [string]$script:scopeHost } else { 'default' }
    $found = $false
    if ($p.PSObject -and $p.PSObject.Properties[$h]) {
      $hp = $p.$h
      if ($null -ne $hp -and $null -ne $hp.offRight -and $null -ne $hp.offBottom) {
        $or = [int]$hp.offRight
        $ob = [int]$hp.offBottom
        if (Test-HudSavedOffset $or $ob) {
          $script:offRight = $or
          $script:offBottom = $ob
          $found = $true
        }
      }
    }
    if (-not $found -and $null -ne $p.offRight -and $null -ne $p.offBottom) {
      $or = [int]$p.offRight
      $ob = [int]$p.offBottom
      if (Test-HudSavedOffset $or $ob) {
        $script:offRight = $or
        $script:offBottom = $ob
      } else {
        $script:offRight = $pad
        $script:offBottom = $pad
      }
    }
  } catch { }
}

function Save-Pos {
  try {
    $h = if ($script:scopeHost) { [string]$script:scopeHost } else { 'default' }
    $p = [ordered]@{}
    if (Test-Path -LiteralPath $posPath) {
      try {
        $raw = (Get-Content -LiteralPath $posPath -Raw | ConvertFrom-Json)
        if ($raw.PSObject) {
          foreach ($prop in $raw.PSObject.Properties) {
            $p[$prop.Name] = $prop.Value
          }
        }
      } catch { }
    }
    $p[$h] = @{ offRight = $script:offRight; offBottom = $script:offBottom }
    $p['offRight'] = $script:offRight
    $p['offBottom'] = $script:offBottom
    $p['updatedAt'] = (Get-Date).ToUniversalTime().ToString('o')
    ($p | ConvertTo-Json -Compress) | Set-Content -LiteralPath $posPath -Encoding utf8
  } catch { }
}
