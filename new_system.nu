#!/usr/bin/env nix-shell
#! nix-shell -i nu -p nushell gh git git-lfs bat nixfmt

use std/assert

"
╔═══════════════════════════════════════════════════╗
║                                                   ║
║        🚀 Welcome to NixOS Setup Script! 🚀       ║
║                                                   ║
╚═══════════════════════════════════════════════════╝
" | ansi gradient --fgstart '0x40c9ff' --fgend '0x90ee90' | print

let hostname = (input "new system's hostname: ")

cd ~
$env.NIX_CONFIG = "experimental-features = nix-command flakes"

# clone with https (will switch to proper ssh later)
let conf = $env.HOME | path join "nixconf"
if ($conf | path exists | not $in) {
    git clone https://github.com/bizmythy/nixconf.git
}
cd $conf

# disable private flake pull, add hostname
let config_file = ($conf | path join "build_config.json")
let old_config = (open $config_file)
(
    $old_config |
    update flags.enableDirac false |
    update hosts ($old_config | get hosts | append $hostname) |
    save --force $config_file
)

# create subdir for host
let host_dir = [
    $conf
    "hosts"
    $hostname
] | path join
try { mkdir $host_dir }

nixos-rebuild boot --sudo --flake 
