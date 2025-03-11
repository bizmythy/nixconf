# nixconf

Configuration files for NixOS and Home Manager
![image](https://github.com/user-attachments/assets/7e27dec8-1485-4878-88d9-a9dbe81463a1)

## Overview

This config uses [hyprland](https://hyprland.org/) as a window manager, and uses Qt-based applications wherever possible.

It is themed heavily with [Catppuccin](https://catppuccin.com/) Mocha (mauve accent).

## Structure

Each computer hostname has a folder in `hosts` and an entry in the `flake.nix` file. These can then import various host-specific modules.
For now, all computers also import the `home/home.nix` module to use for home manager.

## Other Notes

This config uses [catppuccin-nix](https://github.com/catppuccin/nix) to automatically theme most applications.

I have made an effort to stick primarily to Nix language configuration where possible, as opposed to various `.json`, `.toml`, `.yaml`, etc. files being added by home manager.

The evaluation is curretly a bit slow; speeding this up is a future task.

## TODO:

- [ ] gpg signing github
- [ ] integrate 1password cli for logging into everything, better secrets
- [x] signal encrypted kwallet backend
- [x] firefox buttons at right place at startup
- [x] atuin enter not running for specifically nushell?
      ~~- [ ] sddm on all monitors~~ not real, can't work well with hidpi screens~~
- [x] sddm theme if not broken
- [ ] default apps for xdg-open
- [x] switch to ghostty
- [x] 1password autostart in background?
- [x] fix zed settings
- [ ] solaar setup
- [x] default monitor settings
- [ ] terminal search
- [ ] display audio from all displays not working (maybe caused by display mirror?)
