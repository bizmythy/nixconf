{ pkgs }:
pkgs.writers.writePython3Bin "hyprlaunch" {
  libraries = with pkgs.python3Packages; [
    hyprpy
    click
  ];
} (builtins.readFile ./main.py)
