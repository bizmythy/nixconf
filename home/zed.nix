{
  config,
  pkgs,
  lib,
  ...
}:

{
  catppuccin.zed.enable = true;
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
      buffer_font_family = "JetBrainsMono Nerd Font";

      theme = {
        light = lib.mkDefault "Catppuccin Latte";
        dark = lib.mkDefault "Catppuccin Mocha";
        mode = "dark";
      };

      load_direnv = "shell_hook";
      base_keymap = "VSCode";

      assistant = {
        enabled = true;
        version = "2";
        default_open_ai_model = null;
        ### PROVIDER OPTIONS
        ### zed.dev models { claude-3-5-sonnet-latest } requires github connected
        ### anthropic models { claude-3-5-sonnet-latest claude-3-haiku-latest claude-3-opus-latest  } requires API_KEY
        ### copilot_chat models { gpt-4o gpt-4 gpt-3.5-turbo o1-preview } requires github connected
        default_model = {
          provider = "zed.dev";
          model = "claude-3-5-sonnet-latest";
        };

        # inline_alternatives = [
        #     {
        #         provider = "copilot_chat";
        #         model = "gpt-3.5-turbo";
        #     }
        # ];
      };
    };
    # userKeymaps = {
    #   a = "";
    # };
  };
}
