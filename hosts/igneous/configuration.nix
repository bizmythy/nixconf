{
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot = {
    # start amd driver at boot
    initrd.kernelModules = [ "amdgpu" ];
    # enable kernel for disc drive
    kernelModules = [ "sg" ];
    # support ntfs for mounting windows partition
    supportedFilesystems = [ "ntfs" ];
  };

  # mount windows partition
  fileSystems."/mnt/windows" = {
    device = "/dev/nvme0n1p3";
    fsType = "ntfs";
    options = [
      "rw"
      "uid=1000"
      "gid=100"
    ];
  };

  # fix clock for windows dual boot
  time.hardwareClockInLocalTime = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
