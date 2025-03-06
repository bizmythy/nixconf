{
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
      "proto"
    ];
    userKeymaps = [
      # -----KEYBINDS-----
      {
        context = "Workspace";
        bindings = {
          "ctrl-b" = "workspace::ToggleLeftDock";
          "alt-h" = "workspace::ActivatePaneLeft";
          "alt-j" = "workspace::ActivatePaneDown";
          "alt-k" = "workspace::ActivatePaneUp";
          "alt-l" = "workspace::ActivatePaneRight";
        };
      }
    ];

    userSettings = {
      # -----EDITOR CONFIG-----
      autosave.after_delay.milliseconds = 500;

      base_keymap = "VSCode";
      vim_mode = true;
      cursor_blink = false;
      relative_line_numbers = true;
      # scroll_beyond_last_line = "off";

      # -----THEMING AND STYLE-----
      ui_font_size = 16;
      buffer_font_size = 16;
      buffer_font_family = "JetBrainsMono Nerd Font";

      theme = {
        light = lib.mkDefault "Catppuccin Latte";
        dark = lib.mkDefault "Catppuccin Mocha";
        mode = "dark";
      };
      icon_theme = {
        light = "Catppuccin Latte";
        dark = "Catppuccin Mocha";
        mode = "dark";
      };

      # -----LANGUAGE SETUP-----
      load_direnv = "shell_hook";

      file_types = {
        CMake = [
          "CMakeLists.txt"
          "cmake"
        ];
      };

      languages = {
        Markdown.soft_wrap = "editor_width";
      };

      # -----ASSISTANT FEATURES-----
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
  };
}
