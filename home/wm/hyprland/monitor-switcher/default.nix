{
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  monitorConfig = import ../monitor-config.nix;
  hostMonitorConfig = monitorConfig.hosts.${osConfig.networking.hostName} or { };
  profileLabels = [
    "default"
  ]
  ++ lib.sort lib.lessThan (lib.attrNames (hostMonitorConfig.profiles or { }));
  profilesJson = pkgs.writeText "hypr-monitor-profiles.json" (
    builtins.toJSON {
      profiles = map (label: {
        inherit label;
        useTablet = ((hostMonitorConfig.profiles or { }).${label} or { }).useTablet or false;
      }) profileLabels;
      tabletHeadlessName = monitorConfig.tabletHeadless.name;
    }
  );
  python = pkgs.python3.withPackages (pythonPackages: [ pythonPackages.click ]);
  monitorProfileSelector = pkgs.writeShellApplication {
    name = "hypr-monitor-profile";
    runtimeInputs = [
      pkgs.fuzzel
      pkgs.hyprland
      pkgs.libnotify
      python
    ];
    text = ''
      exec ${lib.getExe python} ${./hypr-monitor-profile.py} --profiles-json ${profilesJson} "$@"
    '';
  };
in
{
  home.packages = [ monitorProfileSelector ];
}
