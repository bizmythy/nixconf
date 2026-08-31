{
  lib,
  pkgs,
}:

pkgs.buildGo126Module {
  pname = "herdrctl";
  version = "0.1.0";

  src = ./.;
  vendorHash = "sha256-7K17JaXFsjf163g5PXCb5ng2gYdotnZ2IDKk8KFjNj0=";

  nativeBuildInputs = [ pkgs.makeWrapper ];

  # Darwin limits Unix socket paths to 104 bytes. Go's t.TempDir otherwise
  # inherits Nix's deeply nested build directory and exceeds that limit.
  preCheck = ''
    export TMPDIR=/tmp
  '';

  postInstall = ''
    mv "$out/bin/herdr-keybinds" "$out/bin/herdrctl"
    wrapProgram "$out/bin/herdrctl" \
      --prefix PATH : "${
        lib.makeBinPath [
          pkgs.fzf
          pkgs.zoxide
        ]
      }"

    makeWrapper "$out/bin/herdrctl" "$out/bin/lg-herdr-watch" \
      --add-flags watch-lazygit \
      --prefix PATH : "${lib.makeBinPath [ pkgs.lazygit ]}"
  '';

  meta = with lib; {
    description = "Control Herdr extensions from the command line";
    license = licenses.mit;
    platforms = platforms.unix;
    mainProgram = "herdrctl";
  };
}
