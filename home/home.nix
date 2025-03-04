{
  config,
  pkgs,
  inputs,
  vars,
  lib,
  ...
}:

let
  user = "drew";
  homeDir = "/home/${user}";
  diracPath = "${homeDir}/dirac";
  diracGitConf = (pkgs.formats.ini { }).generate ".gitconfig-dirac" {
    user = {
      name = "drew-dirac";
      email = "drew@diracinc.com";
    };
  };
in
{
  imports = [
    ./tty.nix
    ./shell/shell.nix
    ./wm/hyprland.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = user;
  home.homeDirectory = homeDir;

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

  fonts.fontconfig.enable = true;

  # NOTE: if any of these start to get large, break into separate module.
  programs = {
    git = {
      enable = true;
      userEmail = "andrew.p.council@gmail.com";
      userName = "AndrewCouncil";
      delta = {
        enable = true;
        options = {
          side-by-side = true;
        };
      };
      extraConfig = {
        push = {
          autoSetupRemote = true;
        };
        "includeIf \"gitdir:${diracPath}\"" = {
          path = "${diracGitConf}";
        };
      };
    };
    gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
        # aliases = {};
      };
    };
    gh-dash = {
      enable = true;
      settings = {
        repoPaths = {
          "diracq/*" = "~/dirac/*";
        };
      };
    };

    lazygit.enable = true;

    btop = {
      enable = true;
      settings = {
        vim_keys = true;
        theme_background = false;
      };
    };

    # Let Home Manager install and manage itself.
    home-manager.enable = true;
  };

  # Theming
  catppuccin = {
    enable = true;
    flavor = "mocha";
    # kvantum = {
    #   enable = true;
    #   apply = true;
    # };
  };

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
