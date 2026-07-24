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
    # Ad-block custom CSS, should hopefully stay up-to-date with discord ads...
    vencord.extraQuickCss = lib.mkAfter ''
      @import url(https://codeberg.org/ridge/Discord-Adblock/raw/branch/main/discord-adblock.css);
    '';
  };
}
