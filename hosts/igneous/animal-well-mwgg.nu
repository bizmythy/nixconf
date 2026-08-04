#!/usr/bin/env nix-shell
#! nix-shell -i nu
#! nix-shell -p nushell wineWow64Packages.stagingFull curl

const mwgg_version = "0.7.263"
const mwgg_installer_url = "https://github.com/MultiworldGG/MultiworldGG/releases/download/0.7.263/Setup.MultiworldGG.0.7.263.exe"
const mwgg_installer_sha256 = "5c4d9694ab36ac01971933a6eac44863bac4182afb742a1db15107c372e5b532"
const default_game_dir = "~/.local/share/Steam/steamapps/common/Animal Well"
const default_connection = "mwgg://multiworld.gg:54143"
const default_slot = "bizmyth"

def wine-prefix [] {
  $env.HOME | path join ".local/share/animal-well-mwgg"
}

def mwgg-launcher [] {
  wine-prefix
  | path join "drive_c/Program Files/MultiworldGG/MultiworldGGLauncher.exe"
}

def installer-path [] {
  let cache_home = ($env.XDG_CACHE_HOME? | default ($env.HOME | path join ".cache"))
  $cache_home | path join $"animal-well-mwgg/Setup.MultiworldGG.($mwgg_version).exe"
}

def run-in-prefix [executable: string, ...args: string] {
  with-env {WINEPREFIX: (wine-prefix)} {
    ^$executable ...$args
  }
}

def require-file [file: path, description: string] {
  if not ($file | path exists) {
    error make {msg: $"($description) was not found at ($file)"}
  }
}

def verified-installer [] {
  let installer = (installer-path)
  mkdir ($installer | path dirname)

  let existing_hash = if ($installer | path exists) {
    ^sha256sum $installer | split row " " | first
  } else {
    null
  }

  if $existing_hash != $mwgg_installer_sha256 {
    print $"Downloading MultiworldGG ($mwgg_version)..."
    ^curl --fail --location --output $installer $mwgg_installer_url
  }

  let actual_hash = (^sha256sum $installer | split row " " | first)
  if $actual_hash != $mwgg_installer_sha256 {
    error make {msg: $"MultiworldGG installer checksum mismatch: ($actual_hash)"}
  }

  $installer
}

def start-client [connection?: string] {
  let launcher = (mwgg-launcher)
  require-file $launcher "MultiworldGG launcher"
  let connection = ($connection | default $default_connection)

  print $"Connecting to multiworld.gg:54143; enter slot `($default_slot)` when prompted."
  run-in-prefix wine $launcher "ANIMAL WELL Client" $connection
}

# Download and silently install the Windows MultiworldGG build in an isolated
# Wine prefix. Re-run this after changing the pinned version above.
def "main install" [] {
  let installer = (verified-installer)
  mkdir (wine-prefix)
  run-in-prefix wineboot -- --init
  run-in-prefix wine $installer /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-

  require-file (mwgg-launcher) "MultiworldGG launcher"
  print $"MultiworldGG ($mwgg_version) is installed in (wine-prefix)."
}

# Open the full launcher for configuration, generation, and other tools.
def "main launcher" [] {
  let launcher = (mwgg-launcher)
  require-file $launcher "MultiworldGG launcher (run `animal-well-mwgg.nu install` first)"
  run-in-prefix wine $launcher
}

# Open only the ANIMAL WELL client. You can optionally pass the room's
# archipelago:// connection URI.
def "main client" [connection?: string] {
  start-client $connection
}

# Start the Steam-installed game and MWGG client in the same Wine prefix.
def main [
  connection?: string
  --game-dir: path = $default_game_dir
] {
  let game_dir = ($game_dir | path expand)
  let game = ($game_dir | path join "Animal Well.exe")
  require-file $game "ANIMAL WELL executable"
  require-file (mwgg-launcher) "MultiworldGG launcher (run `animal-well-mwgg.nu install` first)"

  cd $game_dir
  run-in-prefix wine start /unix $game
  sleep 2sec
  start-client $connection
}
