{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

{
  # Enable Simple Desktop Display Manager
  services.displayManager.sddm.enable = true;

  # Enable Hyprland
  programs.hyprland.enable = true;

  # Enable KDE Plasma 6
  services.desktopManager.plasma6.enable = true;

}
