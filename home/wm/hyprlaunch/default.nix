{
  pkgs,
  lib,
  ...
}:
let
  script = pkgs.writers.writePython3Bin "hyprlaunch" {
    libraries = with pkgs.python3Packages; [
      hyprpy
      click
    ];
  } (builtins.readFile ./main.py);
in
{
  home.packages = [ script ];
}
