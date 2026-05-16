{
  lib,
  pkgs,
  ...
}:
let
  package = import ./package.nix { inherit lib pkgs; };
in
{
  home.packages = [ package ];
}
