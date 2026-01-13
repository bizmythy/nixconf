#!/usr/bin/env nix-shell
#! nix-shell -i nu -p nushell gh git git-lfs bat nixfmt

use std/assert

def say [msg: string] {
    print $"(ansi cyan_bold)($msg)(ansi reset)"
}

def "main install" [] {
    let hostname = (input "new system's hostname: ")

    cd ~
    $env.NIX_CONFIG = "experimental-features = nix-command flakes"

    let git_user = {
        "user.email": "andrew.p.council@gmail.com"
        "user.name": "bizmythy"
    }

    # set git user conf settings (temp, will come from home manager later)
    $git_user | items { |key, val|
        git config --global $key $val
    }

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

    let base_config_file = ($conf | path join "hosts/xps/configuration.nix")
    cp $base_config_file $host_dir

    cp /etc/nixos/hardware-configuration.nix $host_dir

    # start new branch for this host temporarily
    git checkout -b $hostname
    git add -A
    git commit -m $"adding host ($hostname)"

    nixos-rebuild boot --sudo --flake $".#($hostname)"

    # unset temp git config settings
    $git_user | items { |key, val|
        git config --global --unset $key
    }

    say "finished setup, reboot and set up git properly for ~/nixconf"
}

def "main configure" [] {
    say "configuration stage"
    input "make sure 1password is fully configured."

    say "switching nixconf to use ssh"
    cd ~/nixconf
    git remote set-url origin git@github.com:bizmythy/nixconf.git

    def read [ref: string, work: bool = false] {
        let account = if $work {
            "PLU4HO2JCJF23NNQK2ERWIYIZI"
        } else {
            "L23KMYOBNVHLPGSIPDX7BAQ5LA"
        }
        ^op --account $account read $ref
    }

    say "setting up atuin"
    do {
        let username = (read "op://Private/atuin sync/username")
        let password = (read "op://Private/atuin sync/password")
        let key = (read "op://Private/atuin sync/key")
        atuin login --username $username --password $password --key $key
    }

    say "setting up zed"
    cd ~/.config
    git clone git@github.com:bizmythy/zed.git

    say "setting up codex"
    cd ~
    git clone git@github.com:bizmythy/codex-config.git .codex

    say "setting up dirac"
    cd ~
    mkdir dirac
    cd dirac
    git init
    git clone git@github.com:diracq/buildos-web.git
}

def main [] {
    say "choose a subcommand"
}
