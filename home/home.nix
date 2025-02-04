{
  config,
  pkgs,
  inputs,
  vars,
  ...
}:

{
  imports = [
    ./alacritty.nix
    ./hyprland.nix
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

  fonts.fontconfig.enable = true;

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  home = {
    shellAliases = {
      ls = "eza";
      lg = "lazygit";
    };
    sessionVariables = {
      EDITOR = "nvim";
      FLAKE = vars.flakePath;
    };
  };

  # NOTE: if any of these start to get large, break into separate module.
  programs = {
    zsh.enable = true;
    bash.enable = true;
    nushell.enable = true;

    git = {
      userEmail = "andrew.p.council@gmail.com";
      userName = "AndrewCouncil";
    };

    atuin = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
      enableNushellIntegration = true;
    };

    lazygit.enable = true;
    zellij.enable = true;
    starship.enable = true;

    # Let Home Manager install and manage itself.
    home-manager.enable = true;
  };

  # Theming
  catppuccin.enable = true;

  catppuccin.kvantum = {
    enable = true;
    apply = true;
  };

  qt = {
    enable = true;
    platformTheme.name = "kvantum";
    style.name = "kvantum";
  };

  # stylix = {
  #   targets.qt = {
  #     platform = "kvantum";
  #     style.name = "kvantum";
  #   };
  #   enable = true;
  #   polarity = "dark";
  #   image = pkgs.fetchurl {
  #     url = "https://filedn.com/l0xkAHTdfcEJNc2OW7dfBny/purple_crystals.jpg";
  #     sha256 = "0fyrzlbx6ii9nzpn2vpl45vdq9hh87af18d3sjpvv66cbsc9vwga";
  #   };
  #   base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
  #   cursor = {
  #     name = "phinger-cursors-dark";
  #     package = pkgs.phinger-cursors;
  #     size = 32;
  #   };

  #   fonts = let
  #     jetbrains = {
  #       package = pkgs.nerd-fonts.jetbrains-mono;
  #       name = "JetBrainsMono Nerd Font";
  #     };
  #   in {
  #     serif = jetbrains;
  #     sansSerif = jetbrains; 
  #     monospace = jetbrains;
  #   };
  # };
}

