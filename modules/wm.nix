{
  lib,
  pkgs,
  ...
}:

let
  sddmTheme = pkgs.stdenv.mkDerivation {
    name = "sddm-theme";
    src = pkgs.fetchFromGitHub {
      owner = "JaKooLit";
      repo = "simple-sddm-2";
      rev = "84ae7ad47eab5daa9d904b2e33669788d891bd3d";
      hash = "sha256-BkqtSh944QIVyYvXCCU8Pucs/2RpWXlwNFSC9zVlRoc=";
    };
    installPhase = ''
      mkdir -p $out
      cp -R ./* $out/
    '';
  };
in
{
  # Enable Hyprland
  programs.hyprland = {
    enable = true;
  };

  catppuccin.sddm.enable = false;
  services.displayManager = {
    # Enable Simple Desktop Display Manager
    sddm = {
      extraPackages = with pkgs.kdePackages; [
        qt5compat
        qtdeclarative
        qtsvg
      ];
      enable = true;
      wayland.enable = true;
      package = pkgs.kdePackages.sddm;
      theme = "${sddmTheme}";
    };

    # # tui display manager
    # ly = {
    #   enable = true;
    #   settings = {
    #     animation = "colormix";
    #   };
    # };
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  # specialisation.kde.configuration = {
  #   # Enable KDE Plasma 6
  #   services.desktopManager.plasma6.enable = true;
  # };

  environment.systemPackages = with pkgs; [
    hyprpicker
    hyprshot
    hyprsysteminfo
    hyprpaper

    pqiv
    playerctl
    brightnessctl
    udiskie
    networkmanagerapplet
    blueman
    pavucontrol
    swaynotificationcenter
    hyprpolkitagent
    wl-clipboard
    wtype
    bemoji
    wev
    cliphist
  ];
}
