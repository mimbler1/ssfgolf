# Downloads the pinned Godot build (4.7.2-stable, standard win64) into tools/godot and verifies its SHA-512.
#   -WebTemplates  instead installs the Web export templates (for tools/web_dev.py) into
#                  %APPDATA%\Godot\export_templates. The archive is ~1.3 GB; only the web files are kept.
param([switch]$WebTemplates)
$ErrorActionPreference = "Stop"
$Version = "4.7.2-stable"
$Dir = Join-Path $PSScriptRoot "godot"
$Zip = Join-Path $Dir "godot.zip"
$Base = "https://github.com/godotengine/godot/releases/download/$Version"
$Asset = "Godot_v${Version}_win64.exe.zip"

New-Item -ItemType Directory -Force $Dir | Out-Null
if ($WebTemplates) { $Asset = "Godot_v${Version}_export_templates.tpz"; $Zip = Join-Path $Dir "templates.tpz" }
Invoke-WebRequest "$Base/$Asset" -OutFile $Zip
Invoke-WebRequest "$Base/SHA512-SUMS.txt" -OutFile (Join-Path $Dir "SHA512-SUMS.txt")
$expected = (Select-String -Path (Join-Path $Dir "SHA512-SUMS.txt") -Pattern ([regex]::Escape($Asset))).Line.Split(" ")[0]
$actual = (Get-FileHash $Zip -Algorithm SHA512).Hash.ToLower()
if ($expected -ne $actual) { Remove-Item $Zip; throw "Checksum mismatch for $Asset" }
if ($WebTemplates) {
  $Dest = Join-Path $env:APPDATA "Godot/export_templates/$($Version.Replace('-', '.'))"
  New-Item -ItemType Directory -Force $Dest | Out-Null
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [System.IO.Compression.ZipFile]::OpenRead($Zip)
  try {
    foreach ($entry in $archive.Entries) {
      if ($entry.Name -eq "version.txt" -or $entry.Name -like "web_*") {
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $Dest $entry.Name), $true)
      }
    }
  } finally { $archive.Dispose() }
  Remove-Item $Zip
  Write-Host "Web export templates installed to $Dest"
  exit 0
}
Expand-Archive $Zip -DestinationPath $Dir -Force
Remove-Item $Zip
Write-Host "Godot $Version installed to $Dir"
