{ pkgs }:
pkgs.writers.writePython3Bin "archive" {
  libraries = with pkgs.python3Packages; [
    click
    tqdm
    zstandard
  ];
} (builtins.readFile ./main.py)
