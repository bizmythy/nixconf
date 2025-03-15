{
  lib,
  pkgs,
  ...
}:

let
  fontFamily = "JetBrainsMono Nerd Font";
  fontSize = 12;
  backgroundOpacity = 0.9;
  startCommand = "nerdfetch && zsh";
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
          startCommand
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
      command = startCommand;
      gtk-single-instance = true;

      font-family = fontFamily;
      font-size = fontSize;
      background-opacity = backgroundOpacity;
      cursor-style = "bar";
      cursor-style-blink = false;
      adjust-cursor-thickness = 2;
      shell-integration-features = "no-cursor";

      copy-on-select = "clipboard";
      app-notifications = "no-clipboard-copy";

    };
    enableBashIntegration = true;
    enableZshIntegration = true;
    package = pkgs.ghostty;
  };
}
