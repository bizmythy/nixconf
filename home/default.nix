{
  lib,
  pkgs,
  vars,
  osConfig,
  ...
}:

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
    ./theme.nix
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

    lazydocker = {
      enable = true;
      settings.gui = {
        returnImmediately = true;
        # catppuccin theme for lazydocker
        # theme = {
        #   activeBorderColor = [
        #     "#cba6f7"
        #     "bold"
        #   ];
        #   inactiveBorderColor = [
        #     "#a6adc8"
        #     "bold"
        #   ];
        #   selectedLineBgColor = [
        #     "default"
        #   ];
        #   optionsTextColor = [
        #     "#89b4fa"
        #   ];
        # };
      };
    };

    # Let Home Manager install and manage itself.
    home-manager.enable = true;
  };

  # text expander
  # services.espanso = {
  #   enable = true;
  # };
}
