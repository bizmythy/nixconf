{
  inputs,
  lib,
  osConfig,
  pkgs,
  vars,
  ...
}:

let
  stablePkgs = import inputs.nixpkgs-stable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in
{
  programs.vesktop = lib.mkIf (vars.isPersonal osConfig) {
    enable = true;
    package = stablePkgs.vesktop;
  };
}
