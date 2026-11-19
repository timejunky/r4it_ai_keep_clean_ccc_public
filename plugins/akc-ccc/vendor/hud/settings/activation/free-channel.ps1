# Copyright (c) 2026 ready-4-it
# Free Marketplace activation stub (shop CTA only).

$shopPad = [int](20 * $scale)
$secShop = New-HudSectionPanel -X $shopPad -Y ([int](24 * $scale)) -Width ([int](720 * $scale)) -Height ([int](140 * $scale)) -Theme $th
$licPad.Controls.Add($secShop)
$lblShopTitle = New-HudLabel -Text (Get-HudT 'about.pro.title') -Fore $th.ProGold -Font (New-HudFont 'Segoe UI Semibold' ([float](13 * $scale)) ([System.Drawing.FontStyle]::Bold)) -AutoSize
$lblShopTitle.Location = New-Object System.Drawing.Point($shopPad, $shopPad)
$secShop.Controls.Add($lblShopTitle)
$lblShopBody = New-HudLabel -Text (Get-HudT 'about.pro.body') -Fore $th.TextPrimary -Font (New-HudFont 'Segoe UI' ([float](9 * $scale)))
$lblShopBody.AutoSize = $false
$lblShopBody.Location = New-Object System.Drawing.Point($shopPad, ($lblShopTitle.Bottom + ([int](10 * $scale))))
$lblShopBody.Size = New-Object System.Drawing.Size(([int](680 * $scale)), ([int](44 * $scale)))
$secShop.Controls.Add($lblShopBody)
$lnkShopOnly = New-Object System.Windows.Forms.LinkLabel
$lnkShopOnly.AutoSize = $true
$lnkShopOnly.BackColor = [System.Drawing.Color]::Transparent
$lnkShopOnly.LinkColor = $th.AccentCyan
$lnkShopOnly.ActiveLinkColor = $th.TextPrimary
$lnkShopOnly.VisitedLinkColor = $th.AccentCyan
$lnkShopOnly.Font = New-HudFont 'Segoe UI' ([float](9.5 * $scale))
$lnkShopOnly.Text = 'https://www.ready-4-it.com/akc_ccc'
$lnkShopOnly.Location = New-Object System.Drawing.Point($shopPad, ($lblShopBody.Bottom + ([int](8 * $scale))))
$lnkShopOnly.Add_LinkClicked({
  try { Start-Process 'https://www.ready-4-it.com/akc_ccc' } catch { }
})
$secShop.Controls.Add($lnkShopOnly)
$secShop.Height = $lnkShopOnly.Bottom + $shopPad
$script:LayoutActivationPage = { }
