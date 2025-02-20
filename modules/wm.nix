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

  # Enable Simple Desktop Display Manager
  services.displayManager.sddm.enable = true;
  catppuccin.sddm.enable = false;
  services.displayManager.sddm.wayland.enable = true;

  specialisation.kde.configuration = {
    # Enable KDE Plasma 6
    services.desktopManager.plasma6.enable = true;
  };
}
