{
  pkgs,
  ...
}:
let
  sddmTheme = pkgs.stdenv.mkDerivation {
    name = "sddm-theme";
    src = pkgs.fetchFromGitHub {
      owner = "JaKooLit";
      repo = "simple-sddm-2";
      rev = "84ae7ad47eab5daa9d904b2e33669788d891bd3d";
      hash = "sha256-BkqtSh944QIVyYvXCCU8Pucs/2RpWXlwNFSC9zVlRoc=";
    };
    installPhase = ''
      mkdir -p $out
      cp -R ./* $out/
    '';
  };
in
{
  catppuccin.sddm.enable = false;
  # Simple Desktop Display Manager
  services.displayManager.sddm = {
    extraPackages = with pkgs.kdePackages; [
      qt5compat
      qtdeclarative
      qtsvg
    ];
    enable = true;
    wayland.enable = true;
    package = pkgs.kdePackages.sddm;
    theme = "${sddmTheme}";
  };

  # # tui display manager
  # services.displayManager.ly = {
  #   enable = true;
  #   settings = {
  #     animation = "colormix";
  #   };
  # };
}
