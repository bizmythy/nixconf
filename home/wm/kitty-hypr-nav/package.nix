{
  lib,
  pkgs,
}:
pkgs.buildGo126Module {
  pname = "kitty-hypr-nav";
  version = "0.1.0";

  src = ./.;
  vendorHash = null;

  nativeBuildInputs = [ pkgs.makeWrapper ];

  postInstall = ''
    wrapProgram "$out/bin/kitty-hypr-nav" \
      --prefix PATH : "${lib.makeBinPath [ pkgs.kitty ]}"
  '';

  meta = with lib; {
    description = "Kitty-aware Hyprland horizontal focus navigation";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "kitty-hypr-nav";
  };
}
