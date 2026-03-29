{
  pkgs,
  ...
}:
let
  script = import ./package.nix { inherit pkgs; };
in
{
  home.packages = [ script ];
}
