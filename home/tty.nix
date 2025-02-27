{ config, pkgs, ... }:

let
  fontFamily = "JetBrainsMono Nerd Font";
  fontSize = 12;
  backgroundOpacity = 0.9;
in
{
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        opacity = backgroundOpacity;
      };

      scrolling.history = 10000;

      selection.save_to_clipboard = true;

      terminal.shell = {
        program = "zsh";
        args = [
          "-c"
          "nerdfetch && nu"
        ];
      };

      font = {
        normal = {
          family = fontFamily;
          style = "Regular";
        };
        bold = {
          family = fontFamily;
          style = "Bold";
        };
        italic = {
          family = fontFamily;
          style = "Italic";
        };
        bold_italic = {
          family = fontFamily;
          style = "Bold Italic";
        };
        size = fontSize;
      };
    };
  };

  programs.ghostty = {
    enable = true;
    settings = {
      font-family = fontFamily;
      font-size = fontSize;
      background-opacity = backgroundOpacity;
      copy-on-select = true;
    };
    enableBashIntegration = true;
    enableZshIntegration = true;
  };
}
