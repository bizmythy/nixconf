{
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
  ];

  services.fwupd.enable = true;

  laptop.enable = true;

  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver # For Broadwell (2014) or newer processors. LIBVA_DRIVER_NAME=iHD
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
