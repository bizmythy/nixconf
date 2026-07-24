{
  inputs,
  lib,
  osConfig,
  pkgs,
  vars,
  ...
}:

{
  programs.vesktop = lib.mkIf (vars.isPersonal osConfig) {
    enable = true;
    # Ad-block custom CSS, should hopefully stay up-to-date with discord ads...
    vencord.extraQuickCss = lib.mkAfter ''
      @import url(https://codeberg.org/ridge/Discord-Adblock/raw/branch/main/discord-adblock.css);
    '';
  };
}
