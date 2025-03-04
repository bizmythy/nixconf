# nixconf
Configuration files for NixOS and Home Manager

## Structure
Each computer hostname has a folder in `hosts` and an entry in the `flake.nix` file. These can then import various host-specific modules.
For now, all computers also import the `home/home.nix` module to use for home manager.

## Other Notes
This config uses [catppuccin-nix](https://github.com/catppuccin/nix) to automatically theme most applications.

I have made an effort to stick primarily to Nix language configuration where possible, as opposed to various `.json`, `.toml`, `.yaml`, etc. files being added by home manager.

The evaluation is curretly a bit slow; speeding this up is a future task.
