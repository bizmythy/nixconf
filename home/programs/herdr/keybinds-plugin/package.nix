{
  lib,
  pkgs,
}:

pkgs.buildGo126Module {
  pname = "herdr-keybinds";
  version = "0.1.0";

  src = ./.;
  vendorHash = "sha256-7K17JaXFsjf163g5PXCb5ng2gYdotnZ2IDKk8KFjNj0=";

  meta = with lib; {
    description = "Herdr keybinding helper plugin";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "herdr-keybinds";
  };
}
