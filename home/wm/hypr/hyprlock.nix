{
  lib,
  pkgs,
  osConfig,
  vars,
  ...
}:
let
  isWork = builtins.elem osConfig.networking.hostName [
    "drewdirac"
    "drewdiracpc"
  ];
  lockScreenTimeout = 60 * 10; # inactive seconds before lock screen
in
{
  programs.hyprlock = {
    enable = true;
    # settings = {};
  };
  services.hypridle = lib.mkIf isWork {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock"; # avoid starting multiple hyprlock instances.
        before_sleep_cmd = "loginctl lock-session"; # lock before suspend.
        after_sleep_cmd = "hyprctl dispatch dpms on"; # to avoid having to press a key twice to turn on the display.
      };
      listener = [
        {
          timeout = lockScreenTimeout;
          on-timeout = "loginctl lock-session"; # lock screen when timeout has passed
        }
      ];
    };
  };
}
