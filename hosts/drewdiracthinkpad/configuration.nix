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
  services.libinput.enable = true;

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
