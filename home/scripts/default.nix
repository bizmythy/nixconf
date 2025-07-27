{
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    (writeScriptBin "flakeup" (builtins.readFile ./flakeup.nu))
  ];
}
