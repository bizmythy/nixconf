{
  lib,
  pkgs,
  ...
}:
let
  package = import ./package.nix { inherit lib pkgs; };
in
{
  home.packages = [ package ];

  systemd.user.services.kitty-hypr-nav = {
    Unit = {
      Description = "Kitty-aware Hyprland navigation daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = "${lib.getExe package} daemon";
      Restart = "on-failure";
      RestartSec = 1;
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
