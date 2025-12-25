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
      enable = true;
      autoStart = true;
      openFirewall = true;
    };

    # # vnc server
    # services.wayvnc = {
    #   enable = false;
    #   autoStart = false;
    #   openFirewall = true;
    # };
  };
}
