{
  lib,
  pkgs,
  platform,
  vars,
  ...
}:

let
  fontFamily = "JetBrainsMono Nerd Font";
  fontSize = 12;
  backgroundOpacity = if platform.isDarwin then 1.0 else 0.9;
in
{
  programs.ghostty = {
    enable = true;
    settings = {
      # GUI-launched Ghostty on macOS does not inherit the Nix profile PATH.
      command = if platform.isDarwin then lib.getExe pkgs.nushell else vars.defaults.shell;

      font-family = fontFamily;
      font-size = fontSize;
      background-opacity = backgroundOpacity;
      cursor-style = "bar";
      cursor-style-blink = false;
      adjust-cursor-thickness = 2;
      shell-integration-features = "no-cursor";
      keybind = [
        "ctrl+enter=unbind"
        "ctrl+shift+enter=unbind"
      ];

      copy-on-select = "clipboard";
      app-notifications = "no-clipboard-copy";
      confirm-close-surface = false;
      link-url = true;
    }
    // lib.optionalAttrs platform.isDarwin {
      # On Linux the catppuccin module supplies the theme.
      theme = "Catppuccin Mocha";
    };
    enableBashIntegration = false;
    enableZshIntegration = true;
    enableFishIntegration = true;
    package = if platform.isLinux then pkgs.ghostty else null;
  };
}
