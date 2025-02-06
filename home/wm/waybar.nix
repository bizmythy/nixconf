{ config, ... }:

{
  catppuccin.waybar = {
    enable = true;
    mode = "createLink";
  };

  programs.waybar = {
    enable = true;
    style = ./waybar.css;
  };
}
