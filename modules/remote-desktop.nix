{
  config,
  lib,
  vars,
  ...
}:
{
  config = lib.mkIf (vars.isPersonal config) {
    # low-latency desktop/game streaming
    services.sunshine = {
      enable = false; # TEMP
      autoStart = false;
      openFirewall = true;
    };
  };
}
