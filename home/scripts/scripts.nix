{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    (writers.writeNuBin "flakeup" builtins.readFile ./flakeup.nu)
  ];
}
