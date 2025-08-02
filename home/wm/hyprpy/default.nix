{
  pkgs,
  lib,
  ...
}:
let
  script = pkgs.writers.writePython3Bin "hyprpy-ctl" {
    libraries = [ pkgs.python3Packages.hyprpy ];
  } builtins.readFile ./main.py;
in
{
  home.packages = [ script ];
}
