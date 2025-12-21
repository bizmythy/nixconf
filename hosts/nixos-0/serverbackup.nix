{
  lib,
  pkgs,
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
  environment.systemPackages = [ serverBackupScript ];

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
}
