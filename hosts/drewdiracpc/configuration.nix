{
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
  ];

  config = {
    # This value determines the NixOS release from which the default
    # settings for stateful data, like file locations and database versions
    # on your system were taken. It‘s perfectly fine and recommended to leave
    # this value at the release version of the first install of this system.
    # Before changing this value read the documentation for this option
    # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
    system.stateVersion = "25.05";
    
    boot.kernelPackages = pkgs.linuxPackages_latest;

    hardware = {
      graphics = {
        extraPackages = with pkgs; [
          intel-compute-runtime
          intel-media-driver
        ];
      };
      enableRedistributableFirmware = true;
    };
  };
}
