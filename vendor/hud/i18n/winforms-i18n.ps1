# Copyright (c) 2026 ready-4-it
# CCC HUD i18n — AKC-shaped flat JSON catalogs (en baseline + overlay).
# Defines: Initialize-HudI18n, Get-HudT, Get-HudLang, Set-HudLang, Get-HudSupportedLangs
# Twig help: Invoke-HudTwigHelp (node + twig) with templates under i18n/templates/

$script:HudI18nMessages = @{}
$script:HudI18nLang = 'en'
$script:HudI18nSupported = @('en', 'de', 'fr', 'lb', 'tr', 'pt', 'es', 'it')

function Get-HudI18nRoot {
  if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'en.json')) { return $PSScriptRoot }
  $cands = @(
    (Join-Path $PSScriptRoot 'i18n'),
    (Join-Path $env:USERPROFILE '.cursor\plugins\local\ai-keep-clean-ccc\vendor\hud\i18n')
  )
  foreach ($c in $cands) {
    if (Test-Path -LiteralPath (Join-Path $c 'en.json')) { return $c }
  }
  return $PSScriptRoot
}

function Get-HudSupportedLangs { return @($script:HudI18nSupported) }

function Resolve-HudLangCode([string]$requested) {
  $req = if ([string]::IsNullOrWhiteSpace($requested)) { 'auto' } else { $requested.Trim().ToLowerInvariant() }
  if ($req -eq 'auto') {
    try {
      $ui = [System.Globalization.CultureInfo]::CurrentUICulture.Name.ToLowerInvariant()
    } catch {
      $ui = 'en'
    }
    $req = $ui
  }
  $root = Get-HudI18nRoot
  if (Test-Path -LiteralPath (Join-Path $root "$req.json")) { return $req }
  $prefix = ($req -split '-')[0]
  if ($prefix -ne $req -and (Test-Path -LiteralPath (Join-Path $root "$prefix.json"))) { return $prefix }
  return 'en'
}

function Initialize-HudI18n([string]$Language = 'auto') {
  $root = Get-HudI18nRoot
  $code = Resolve-HudLangCode $Language
  $script:HudI18nLang = $code
  $messages = [ordered]@{}
  foreach ($layer in @('en', $code)) {
    $path = Join-Path $root "$layer.json"
    if (-not (Test-Path -LiteralPath $path)) { continue }
    try {
      $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8
      $obj = $raw | ConvertFrom-Json
      foreach ($p in $obj.PSObject.Properties) {
        $messages[$p.Name] = [string]$p.Value
      }
    } catch { }
  }
  $script:HudI18nMessages = $messages
  return $code
}

function Get-HudLang { return [string]$script:HudI18nLang }

function Set-HudLang([string]$Language) {
  return (Initialize-HudI18n $Language)
}

function Get-HudT {
  param(
    [Parameter(Mandatory)][string]$Key,
    [hashtable]$Vars
  )
  $s = $script:HudI18nMessages[$Key]
  if ($null -eq $s -or $s -eq '') { $s = $Key }
  if ($Vars) {
    foreach ($k in @($Vars.Keys)) {
      $s = $s -replace "\{$k\}", [string]$Vars[$k]
    }
  }
  return [string]$s
}

function Get-HudLangLabel([string]$code) {
  switch ($code) {
    'en' { return 'English' }
    'de' { return 'Deutsch' }
    'fr' { return 'Français' }
    'lb' { return 'Lëtzebuergesch' }
    'tr' { return 'Türkçe' }
    'pt' { return 'Português' }
    'es' { return 'Español' }
    'it' { return 'Italiano' }
    'auto' { return (Get-HudT 'lang.auto') }
    default { return $code }
  }
}

function Invoke-HudTwigHelp {
  param([string]$Topic = 'overview')
  $root = Get-HudI18nRoot
  $render = Join-Path $root 'render-twig.mjs'
  if (-not (Test-Path -LiteralPath $render)) {
    return @{
      title = (Get-HudT "help.topic.$Topic.title")
      body  = (Get-HudT "help.topic.$Topic.body")
    }
  }
  try {
    $lang = Get-HudLang
    $raw = & node $render --lang $lang --topic $Topic 2>$null
    if ([string]::IsNullOrWhiteSpace([string]$raw)) {
      return @{
        title = (Get-HudT "help.topic.$Topic.title")
        body  = (Get-HudT "help.topic.$Topic.body")
      }
    }
    $j = $raw | ConvertFrom-Json
    return @{
      title = [string]$j.title
      body  = [string]$j.body
    }
  } catch {
    return @{
      title = (Get-HudT "help.topic.$Topic.title")
      body  = (Get-HudT "help.topic.$Topic.body")
    }
  }
}
