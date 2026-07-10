{
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot = {
    # start amd driver at boot
    initrd.kernelModules = [ "amdgpu" ];
    # Enable AMDGPU HDMI 2.1 FRL once using Linux 7.2+.
    # kernelParams = [ "amdgpu.dc_feature_mask=0x400" ];
    # enable kernel for disc drive
    kernelModules = [ "sg" ];
    # support ntfs for mounting windows partition
    supportedFilesystems = [ "ntfs" ];
  };

  hardware.graphics.extraPackages = with pkgs; [ rocmPackages.clr.icd ];

  environment.systemPackages = with pkgs; [
    amd-ctk
    amd-container-runtime
  ];
  virtualisation.docker.daemon.settings.runtimes.amd = {
    path = lib.getExe pkgs.amd-container-runtime;
  };

  services.ollama = {
    enable = false;
    openFirewall = true;
    environmentVariables = {
      OLLAMA_MODELS = "/mnt/storage/ollama";
    };
  };

  networking.firewall.allowedTCPPorts = [
    41707 # pi remote-control
  ];

  fileSystems = {
    # mount windows partition
    "/mnt/windows" = {
      device = "/dev/disk/by-uuid/5E06928506925DB9";
      fsType = "ntfs";
      options = [
        "rw"
        "uid=1000"
        "gid=100"
      ];
    };

    # mount storage drive
    "/mnt/storage" = {
      device = "/dev/disk/by-uuid/6422C81A22C7EF5C";
      fsType = "ntfs";
      options = [
        "rw"
        "uid=1000"
        "gid=100"
      ];
    };
  };

  # fix clock for windows dual boot
  time.hardwareClockInLocalTime = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
