{
  vars,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix # generated at runtime by nixos-infect
    ./containers.nix
    ./serverbackup.nix
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.hostName = "nixos-0";
  networking.domain = "";

  services.openssh = {
    enable = true;
    ports = [ 52681 ]; # random port, unlikely to be random scanned
  };

  # set ssh authorized keys
  users.users =
    let
      authorizedKeys = {
        openssh.authorizedKeys.keys = [
          ''ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGogIJ4uaReEMnM8eRedZh0OVq/4AAs4H8xdiWjvf6YF''
        ];
      };
    in
    {
      root = authorizedKeys;
      "${vars.user}" = authorizedKeys;
    };

  system.stateVersion = "23.11";
}
