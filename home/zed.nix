{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.zed-editor = {
    enable = true;
    extensions = [
      "catppuccin"
      "nix"
    ];
    userSettings = {
      vim_mode = true;

      autosave.after_delay.milliseconds = 500;

      ui_font_size = 16;
      buffer_font_size = 16;

      theme = {
        light = "Catppuccin Latte";
        dark = "Catppuccin Mocha";
        mode = "dark";
      };

    };
    # userKeymaps = {
    #   a = "";
    # };
  };
}
