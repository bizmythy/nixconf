{
  lib,
  pkgs,
  ...
}:

{
  # Enable Hyprland
  programs.hyprland = {
    enable = true;
  };

  catppuccin.sddm.enable = false;
  services.displayManager = {
    # Enable Simple Desktop Display Manager
    sddm = {
      enable = true;
      wayland.enable = true;
      package = pkgs.kdePackages.sddm;
      theme = "breeze";
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
