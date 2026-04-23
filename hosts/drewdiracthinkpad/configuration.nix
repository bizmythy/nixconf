{
  lib,
  pkgs,
  ...
}:

{
  imports = lib.optionals (builtins.pathExists ./hardware-configuration.nix) [
    ./hardware-configuration.nix
  ];

  laptop.enable = true;
  services.fwupd.enable = true;

  # The built-in Raydium touchscreen is detected, but the dedicated
  # raydium_i2c_ts driver does not expose a usable touch device to Hyprland.
  # Let the generic HID multitouch stack claim it instead.
  boot.blacklistedKernelModules = [ "raydium_i2c_ts" ];
  boot.kernelModules = [ "hid_multitouch" ];

  boot.initrd.luks.devices."luks-30ead0c5-44cb-4dae-9620-f72db25f725b".device =
    "/dev/disk/by-uuid/30ead0c5-44cb-4dae-9620-f72db25f725b";

  hardware = {
    graphics.extraPackages = with pkgs; [
      intel-compute-runtime
      intel-media-driver
    ];
    enableRedistributableFirmware = true;
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
