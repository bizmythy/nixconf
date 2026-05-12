{
  inputs,
  pkgs,
  ...
}:

{
  # Enable Hyprland
  programs.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
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
    hyprpaper

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
