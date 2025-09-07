{
  lib,
  pkgs,
  vars,
  osConfig,
  ...
}:

let
  cursor = {
    name = "phinger-cursors-light";
    package = pkgs.phinger-cursors;
    size = 24;
  };
in
{
  imports = [
    # keep-sorted start
    ./firefox.nix
    ./gh.nix
    ./lazygit.nix
    ./nvim.nix
    ./op.nix
    ./scripts
    ./shell.nix
    ./spotify-player.nix
    ./ssh-git.nix
    ./tty/tty.nix
    ./vesktop.nix
    ./wm
    ./xdg-mime.nix
    # keep-sorted end
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = vars.user;
  home.homeDirectory = vars.home;

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.11"; # Please read the comment before changing.

  # home.packages = with pkgs; [
  # ];

  # NOTE: if any of these start to get large, break into separate module.
  programs = {
    btop = {
      enable = true;
      settings = {
        vim_keys = true;
        theme_background = false;
      };
    };

    bat = {
      enable = true;
      config = {
        style = "header-filename,rule,snip";
        color = "always";
      };
      syntaxes = {
        nushell.src = pkgs.fetchurl {
          url = "https://gist.githubusercontent.com/melMass/294c21a113d0bd329ae935a79879fe04/raw/nushell.sublime-syntax";
          hash = "sha256-QSjnGrv3o9qZ74b6Hk6pXJ6fx2Dq8U0cu9fyd51zokw=";
        };
      };
    };

    chromium = {
      enable = true;
      commandLineArgs = lib.mkIf osConfig.nvidiaEnable [
        "--ozone-platform-hint=x11"
      ];
    };

    helix = {
      enable = true;
    };

    # simple image viewer
    feh = {
      enable = true;
    };

    # Let Home Manager install and manage itself.
    home-manager.enable = true;
  };

  # text expander
  # services.espanso = {
  #   enable = true;
  # };

  # catppuccin theme for lazydocker
  xdg.configFile."lazydocker/config.yml".source = (pkgs.formats.yaml { }).generate "config.yml" {
    gui = {
      returnImmediately = true;
      theme = {
        activeBorderColor = [
          "#cba6f7"
          "bold"
        ];
        inactiveBorderColor = [
          "#a6adc8"
          "bold"
        ];
        selectedLineBgColor = [
          "default"
        ];
        optionsTextColor = [
          "#89b4fa"
        ];
      };
    };
  };

  fonts.fontconfig.enable = true;

  # Theming
  catppuccin = {
    enable = true;
    flavor = "mocha";
    # kvantum = {
    #   enable = true;
    #   apply = true;
    # };
    mako.enable = false;
  };

  home.pointerCursor = cursor;

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    cursorTheme = cursor;
  };

  qt = {
    enable = true;
    platformTheme.name = "kvantum";
    style.name = "kvantum";

    # fixes for kvantum and icon theme to be applied to kde apps
    kde.settings = {
      "kdeglobals" = {
        "UiSettings" = {
          "ColorScheme" = "Kvantum";
        };
        "Icons" = {
          "Theme" = "Papirus-Dark";
        };
      };
    };
  };
}
