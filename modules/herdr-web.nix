{
  config,
  lib,
  pkgs,
  vars,
  ...
}:

let
  cfg = config.services.herdr-web;
  allowedHosts = lib.concatStringsSep "," cfg.allowedHosts;
  herdrShell = pkgs.writeShellScript "herdr-web-shell" ''
    exec ${lib.getExe pkgs.herdr} "$@"
  '';
  launcher = pkgs.writeShellScript "herdr-web-start" ''
    addresses="$(${lib.getExe' pkgs.iproute2 "ip"} -json address show scope global \
      | ${lib.getExe pkgs.jq} -r \
        '[.[].addr_info[]? | .local] | unique | join(",")')"
    export GHOSTTY_ALLOWED_HOSTS=${lib.escapeShellArg allowedHosts}
    if [[ -n "$addresses" ]]; then
      export GHOSTTY_ALLOWED_HOSTS="$GHOSTTY_ALLOWED_HOSTS,$addresses"
    fi
    exec ${lib.getExe pkgs.herdr-web}
  '';
in
{
  options.services.herdr-web = {
    enable = lib.mkEnableOption "a fullscreen Herdr terminal served by ghostty-web";

    port = lib.mkOption {
      type = lib.types.port;
      default = 7681;
      description = "TCP port on which the Herdr web terminal listens.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to open the web terminal port in the firewall.";
    };

    allowedHosts = lib.mkOption {
      type = with lib.types; listOf str;
      default = [
        config.networking.hostName
        "${config.networking.hostName}.local"
      ];
      description = "Hostnames accepted by ghostty-web's same-origin checks.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.herdr-web = {
      description = "Fullscreen Herdr web terminal";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        HOME = vars.home;
        HOST = "0.0.0.0";
        PATH = lib.mkForce "${vars.home}/.nix-profile/bin:/etc/profiles/per-user/${vars.user}/bin:/run/current-system/sw/bin:/run/wrappers/bin";
        PORT = toString cfg.port;
        SHELL = herdrShell;
      };

      serviceConfig = {
        ExecStart = launcher;
        Group = "users";
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0077";
        User = vars.user;
        WorkingDirectory = vars.home;
      };
    };

    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall [ cfg.port ];
  };
}
