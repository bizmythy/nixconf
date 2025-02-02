{
  config,
  pkgs,
  inputs,
  ...
}:

{
  specialisation = {
    kdewm.configuration = {
      # Enable the KDE Plasma Desktop Environment.
      services.displayManager.sddm.enable = true;
      services.desktopManager.plasma6.enable = true;
    };

    hyprwm.configuration = {
      # Enable Hyprland
      programs.hyprland.enable = true;
    };
  };
}
