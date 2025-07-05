{
  pkgs,
  vars,
  ...
}:

let
  fontFamily = "JetBrainsMono Nerd Font";
  fontSize = 12;
  backgroundOpacity = 0.9;
  scrollback = 10000;
in
{
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        opacity = backgroundOpacity;

        padding = {
          x = 10;
          y = 10;
        };
        dynamic_padding = true;
      };

      scrolling.history = 10000;

      selection.save_to_clipboard = true;

      terminal.shell.program = vars.defaults.shell;

      cursor = {
        style = {
          shape = "Beam";
          blinking = "Off";
        };
        unfocused_hollow = true;
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

  programs.ghostty =
    let
      bloomAmmount = "0.03";
      ghosttyShaders = pkgs.stdenv.mkDerivation {
        name = "bloom-shader";
        src = pkgs.fetchFromGitHub {
          owner = "hackr-sh";
          repo = "ghostty-shaders";
          rev = "a17573fb254e618f92a75afe80faa31fd5e09d6f";
          hash = "sha256-p0speO5BtLZZwGeuRvBFETnHspDYg2r5Uiu0yeqj1iE=";
        };

        postPatch = ''
          substituteInPlace bloom.glsl --replace-fail "0.2;" "${bloomAmmount};"
        '';

        installPhase = ''
          mkdir -p $out
          cp -R ./* $out/
        '';
      };
    in
    {
      enable = true;
      settings = {
        command = vars.defaults.shell;
        # gtk-single-instance = true;

        font-family = fontFamily;
        font-size = fontSize;
        background-opacity = backgroundOpacity;
        cursor-style = "bar";
        cursor-style-blink = false;
        adjust-cursor-thickness = 2;
        shell-integration-features = "no-cursor";

        copy-on-select = "clipboard";
        app-notifications = "no-clipboard-copy";
        confirm-close-surface = false;
        link-url = true;

        custom-shader = "${ghosttyShaders}/bloom.glsl";
      };
      enableBashIntegration = true;
      enableZshIntegration = true;
      enableFishIntegration = true;
      installBatSyntax = true;
      package = pkgs.ghostty;
    };

  programs.kitty = {
    enable = true;
    font = {
      name = fontFamily;
      size = fontSize;
    };
    shellIntegration.enableZshIntegration = true;

    settings = {
      copy_on_select = "clipboard";
      clear_selection_on_clipboard_loss = true;
      paste_actions = "quote-urls-at-prompt,confirm,confirm-if-large";

      shell = vars.defaults.shell;

      cursor_shape = "beam";
      cursor_blink_interval = 0;

      background_opacity = backgroundOpacity;
      enable_audio_bell = false;

      scrollback_lines = scrollback;
      scrollback_fill_enlarged_window = true;
      focus_follows_mouse = true;

      confirm_os_window_close = 0;
    };
  };
}
