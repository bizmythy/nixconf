{ config, pkgs, ... }:

let
  font_family = "JetBrainsMono Nerd Font";
in
{
  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        normal = {
          family = font_family;
          style = "Regular";
        };
        bold = {
          family = font_family;
          style = "Bold";
        };
        italic = {
          family = font_family;
          style = "Italic";
        };
        bold_italic = {
          family = font_family;
          style = "Bold Italic";
        };
        size = 12;
      };
    };
  };
}
