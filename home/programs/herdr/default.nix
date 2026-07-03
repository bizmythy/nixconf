{ pkgs, ... }:

let
  toml = pkgs.formats.toml { };
in

{
  xdg.configFile."herdr/config.toml".source = toml.generate "herdr-config.toml" (import ./config.nix);
}
