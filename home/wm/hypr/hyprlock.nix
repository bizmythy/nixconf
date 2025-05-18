{
  lib,
  pkgs,
  osConfig,
  vars,
  ...
}:
{
  programs.hyprlock = {
    enable = true;
    # settings = {};
  };
}