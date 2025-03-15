{
  pkgs,
  vars,
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
    ./firefox.nix
    ./git.nix
    ./ssh.nix
    ./shell/shell.nix
    ./tty.nix
    ./wm/hypr/hyprland.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "drew";
  home.homeDirectory = "/home/drew";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.11"; # Please read the comment before changing.

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # home.packages = with pkgs; [
  # ];

  # set default applications
  xdg.mimeApps = {
    enable = true;
    defaultApplications =
      let
        browser = "${vars.defaults.browser}.desktop";
        fileManager = "org.kde.dolphin.desktop";
        editor = "dev.zed.Zed.desktop";
      in
      {
        "text/html" = browser;
        "x-scheme-handler/http" = browser;
        "x-scheme-handler/https" = browser;
        "x-scheme-handler/about" = browser;
        "x-scheme-handler/unknown" = browser;
        "inode/directory" = fileManager;
        "text/plain" = editor;
      };
  };

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
    };

    # Let Home Manager install and manage itself.
    home-manager.enable = true;
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
  };

  home.pointerCursor = cursor;

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.catppuccin-papirus-folders.override {
        accent = "mauve";
        flavor = "mocha";
      };
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
