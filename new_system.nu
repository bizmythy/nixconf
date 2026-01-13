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

cd ~
$env.NIX_CONFIG = "experimental-features = nix-command flakes"

# clone with https to temp location
let tmp = $env.HOME | path join "temp_nixconf"
if ($tmp | path exists | not $in) {
    git clone https://github.com/bizmythy/nixconf.git $tmp
}
cd $tmp

# disable private flake pull
let flags_file = (pwd | path join "build_flags.json")
(
    open $flags_file |
    update enableDirac false |
    save --force $flags_file
)


