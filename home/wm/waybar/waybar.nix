{ config, lib, ... }:

{
  catppuccin.waybar = {
    enable = true;
    mode = "createLink";
  };

  programs.waybar = {
    enable = true;
    style = ./waybar.css;
  };

  xdg.configFile = {
    "waybar/config.jsonc".source = ./config.jsonc;
    "waybar/power_menu.xml".source = ./power_menu.xml;
  };
}
