{
  vars,
  pkgs,
  lib,
  ...
}:
let
  serverBackupScript = pkgs.writers.writeNuBin "serverbackup" ''
    let dirname = "ftbskies"
    let dirpath = ("/home/drew/minecraft" | path join $dirname)

    let now = (date now | format date "%Y-%m-%d-%H-%M-%S")

    let filename = $"($dirname)_($now).tar.zst"

    let workdir = (mktemp --directory)
    cd $workdir

    let output = (
        do {
            ${lib.getExe pkgs.gnutar} --zstd -cvf $filename $dirpath
            ${lib.getExe pkgs.rclone} --config /home/drew/.config/rclone/rclone.conf copy $filename "pcloud-personal:minecraft_backups"
        } | complete
    )

    if ($output.exit_code != 0) {
        print "Backup command exited with error code."
        print $output
    }

    cd
    rm -r $workdir
    exit $output.exit_code
  '';
in
{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix # generated at runtime by nixos-infect
    ./containers.nix
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

  systemd.services.serverbackup = {
    description = "Weekly Minecraft backup to pCloud";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe serverBackupScript;
    };
  };

  systemd.timers.serverbackup = {
    description = "Run serverbackup weekly on Wednesdays at 12:00";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Wed 12:00"; # weekly, noon on Wednesday
      Persistent = true; # catch up if missed
    };
  };
  system.stateVersion = "23.11";
}
