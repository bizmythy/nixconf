{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

{
  services.displayManager.sddm.enable = lib.mkDefault true;
  services.desktopManager.plasma6.enable = lib.mkDefault true;

  specialisation = {
    hyprwm.configuration = {
      # Disable KDE Plasma
      services.displayManager.sddm.enable = false;
      services.desktopManager.plasma6.enable = false;

      # Enable Hyprland
      programs.hyprland.enable = true;
    };
  };
}

