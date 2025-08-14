#!/usr/bin/env nu

let flake = "./flake.nix"

if (($flake | path type) != "file") {
    print $"(ansi red)no flake.nix file found(ansi reset)"
    exit 1
}

nix flake update
git add flake.lock
git commit -m "update flake.lock"
