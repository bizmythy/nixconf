{ config, pkgs, ... }:

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

  home.packages = with pkgs; [
  ];

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

  programs.zsh = {
    enable = true;
    initExtra = ''
      eval "$(atuin init zsh)"
    '';
  };
  programs.bash.enable = true;
  programs.nushell.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  programs.git.userEmail = "andrew.p.council@gmail.com";
  programs.git.userName = "AndrewCouncil";


  programs.zellij = {
    enable = true;
  };

  catppuccin.enable = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
