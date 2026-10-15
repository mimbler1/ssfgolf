# Downloads the pinned Godot build (4.7.2-stable, standard win64) into tools/godot and verifies its SHA-512.
$ErrorActionPreference = "Stop"
$Version = "4.7.2-stable"
$Dir = Join-Path $PSScriptRoot "godot"
$Zip = Join-Path $Dir "godot.zip"
$Base = "https://github.com/godotengine/godot/releases/download/$Version"
$Asset = "Godot_v${Version}_win64.exe.zip"

New-Item -ItemType Directory -Force $Dir | Out-Null
Invoke-WebRequest "$Base/$Asset" -OutFile $Zip
Invoke-WebRequest "$Base/SHA512-SUMS.txt" -OutFile (Join-Path $Dir "SHA512-SUMS.txt")
$expected = (Select-String -Path (Join-Path $Dir "SHA512-SUMS.txt") -Pattern ([regex]::Escape($Asset))).Line.Split(" ")[0]
$actual = (Get-FileHash $Zip -Algorithm SHA512).Hash.ToLower()
if ($expected -ne $actual) { Remove-Item $Zip; throw "Checksum mismatch for $Asset" }
Expand-Archive $Zip -DestinationPath $Dir -Force
Remove-Item $Zip
Write-Host "Godot $Version installed to $Dir"
