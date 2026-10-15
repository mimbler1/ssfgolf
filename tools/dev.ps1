<#
.SYNOPSIS
  Developer launcher for Project Fairway Frenzy.

.EXAMPLE
  ./tools/dev.ps1 db          # start Postgres (Docker)
  ./tools/dev.ps1 backend     # run the backend API on :8080 (foreground)
  ./tools/dev.ps1 server      # run one dedicated game server on UDP 7777, registered with the backend
  ./tools/dev.ps1 servers 3   # run 3 game servers (UDP 7777-7779) in new windows
  ./tools/dev.ps1 client      # run the game client
  ./tools/dev.ps1 clients 2   # run 2 clients with separate local identities (alice, bob, ...)
  ./tools/dev.ps1 all         # db + backend + 2 servers + 2 clients, each in its own window
  ./tools/dev.ps1 test        # all automated tests (sim, solver, backend, end-to-end)
  ./tools/dev.ps1 editor      # open the project in the Godot editor
#>
param(
  [Parameter(Position = 0)][string]$Command = "help",
  [Parameter(Position = 1)][int]$Count = 2
)

$Root = Split-Path -Parent $PSScriptRoot
$GodotConsole = Join-Path $Root "tools/godot/Godot_v4.7.2-stable_win64_console.exe"
$GodotGui = Join-Path $Root "tools/godot/Godot_v4.7.2-stable_win64.exe"
$Client = Join-Path $Root "client"
$Backend = Join-Path $Root "backend"
$Names = @("alice", "bob", "carol", "dave")

function Require-Godot {
  if (-not (Test-Path $GodotConsole)) {
    Write-Error "Godot 4.7.2 not found in tools/godot. See README.md > Setup."
    exit 1
  }
}

function Start-Window([string]$Title, [string]$Cmd) {
  Start-Process powershell -ArgumentList "-NoExit", "-Command", "`$Host.UI.RawUI.WindowTitle='$Title'; $Cmd"
}

switch ($Command) {
  "db" { docker compose -f (Join-Path $Root "docker-compose.yml") up -d postgres }
  "backend" {
    Push-Location $Backend
    if (-not (Test-Path "node_modules")) { npm install }
    $env:MM_FILL_WAIT_MS = "5000"
    node src/index.ts
    Pop-Location
  }
  "server" {
    Require-Godot
    & $GodotConsole --headless --path $Client -- --server --port 7777 --backend http://127.0.0.1:8080 --public-host 127.0.0.1
  }
  "servers" {
    Require-Godot
    for ($i = 0; $i -lt $Count; $i++) {
      $port = 7777 + $i
      Start-Window "Game server $port" "& '$GodotConsole' --headless --path '$Client' -- --server --port $port --backend http://127.0.0.1:8080 --public-host 127.0.0.1"
    }
  }
  "client" { Require-Godot; & $GodotGui --path $Client }
  "clients" {
    Require-Godot
    for ($i = 0; $i -lt $Count; $i++) {
      Start-Process $GodotGui -ArgumentList "--path", "`"$Client`"", "--", "--profile", $Names[$i % 4]
    }
  }
  "all" {
    Require-Godot
    docker compose -f (Join-Path $Root "docker-compose.yml") up -d postgres
    Start-Window "Backend" "Set-Location '$Backend'; if (-not (Test-Path node_modules)) { npm install }; `$env:MM_FILL_WAIT_MS='5000'; node src/index.ts"
    Start-Sleep -Seconds 4
    for ($i = 0; $i -lt 2; $i++) {
      $port = 7777 + $i
      Start-Window "Game server $port" "& '$GodotConsole' --headless --path '$Client' -- --server --port $port --backend http://127.0.0.1:8080 --public-host 127.0.0.1"
    }
    Start-Sleep -Seconds 2
    for ($i = 0; $i -lt $Count; $i++) {
      Start-Process $GodotGui -ArgumentList "--path", "`"$Client`"", "--", "--profile", $Names[$i % 4]
    }
  }
  "test" {
    Require-Godot
    python (Join-Path $Root "tools/sprites/build_character.py") adventurer --check
    & $GodotConsole --headless --path $Client --script res://tests/compile_all.gd
    & $GodotConsole --headless --path $Client --script res://tests/test_characters.gd
    & $GodotConsole --headless --path $Client --script res://tests/test_sim.gd
    & $GodotConsole --headless --path $Client --script res://tests/test_playable.gd
    Push-Location $Backend; npm test; Pop-Location
    python (Join-Path $Root "tools/e2e_online.py")
  }
  "editor" { Require-Godot; & $GodotGui --path $Client --editor }
  default { Get-Help $PSCommandPath -Detailed }
}
