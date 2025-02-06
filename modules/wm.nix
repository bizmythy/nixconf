{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

{
  # Enable Hyprland
  programs.hyprland = {
    enable = true;
  };

  programs.waybar = {
    enable = true;
  };

  specialisation.kde.configuration = {
    # Enable Simple Desktop Display Manager
    services.displayManager.sddm.enable = true;
    # Enable KDE Plasma 6
    services.desktopManager.plasma6.enable = true;
  };
}
