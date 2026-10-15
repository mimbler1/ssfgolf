<#
.SYNOPSIS
  Bakes the roster character sprite sheets (client/assets/characters/*.png + .json).

.DESCRIPTION
  Renders every character in CharacterSkin.ROSTER through every animation with the sprite baker
  scene, then re-imports so Godot picks up the new sheets. Needs a desktop session (it opens a
  small window while it renders).

.EXAMPLE
  ./tools/bake_sprites.ps1            # all characters
  ./tools/bake_sprites.ps1 ace,nana   # only some
#>
param([Parameter(Position = 0)][string]$Only = "")

$Root = Split-Path -Parent $PSScriptRoot
$Godot = Join-Path $Root "tools/godot/Godot_v4.7.2-stable_win64_console.exe"
$Client = Join-Path $Root "client"
$extra = @()
if ($Only -ne "") { $extra = @("--", "--only", $Only) }
& $Godot --path $Client res://scenes/dev/sprite_baker.tscn @extra
& $Godot --headless --path $Client --import
# Sheets are drawn scaled down, so they need mipmaps; BPTC keeps VRAM to ~1 byte per pixel.
Get-ChildItem (Join-Path $Client "assets/characters") -Filter *.png.import | ForEach-Object {
  (Get-Content $_.FullName) `
    -replace '^compress/mode=0', 'compress/mode=2' `
    -replace '^compress/high_quality=false', 'compress/high_quality=true' `
    -replace '^mipmaps/generate=false', 'mipmaps/generate=true' |
    Set-Content -Encoding utf8 $_.FullName
}
& $Godot --headless --path $Client --import
