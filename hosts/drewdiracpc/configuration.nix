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

    boot = {
      kernelPackages = pkgs.linuxPackages_latest;

      # Keep encrypted SSDs fast under Docker/build churn: pass TRIM and skip dm-crypt queues.
      initrd.luks.devices."luks-4dc31d4d-b331-4198-b980-216b74f8b11a" = {
        allowDiscards = true;
        bypassWorkqueues = true;
      };
    };

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
