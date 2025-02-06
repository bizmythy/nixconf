{ config, lib, ... }:

{
  catppuccin.waybar = {
    enable = true;
    mode = "prependImport";
  };

  programs.waybar = {
    enable = true;
    style = ./waybar.css;
  };

  xdg.configFile."waybar/config".source = ./config.jsonc;
}
