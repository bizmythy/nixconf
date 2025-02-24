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
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # catppuccin sdddm theme, not working with kde specialisation
  # services.displayManager.sddm.package = pkgs.kdePackages.sddm;
  catppuccin.sddm.enable = false;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  specialisation.kde.configuration = {
    # Enable KDE Plasma 6
    services.desktopManager.plasma6.enable = true;
  };
}
