{
  pkgs,
  lib,
  ...
}:
let
  # make a script with binary name based on script name
  getName = path: builtins.elemAt (lib.splitString "." (builtins.baseNameOf path)) 0;
  makeScript = path: pkgs.writeScriptBin (getName path) (builtins.readFile path);
in
{
  home.packages = map makeScript [
    ./flakeup.nu
  ];
}
