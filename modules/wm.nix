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

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  specialisation.kde.configuration = {
    # Enable KDE Plasma 6
    services.desktopManager.plasma6.enable = true;
  };
}
