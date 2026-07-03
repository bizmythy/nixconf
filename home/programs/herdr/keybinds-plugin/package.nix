{
  lib,
  pkgs,
}:

pkgs.buildGo126Module {
  pname = "herdr-keybinds";
  version = "0.1.0";

  src = ./.;
  vendorHash = null;

  meta = with lib; {
    description = "Herdr keybinding helper plugin";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "herdr-keybinds";
  };
}
