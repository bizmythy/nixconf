self: super: {
  python3Packages = super.python3Packages.overrideScope (
    python-self: python-super: {
      hyprpy = super.callPackage ./pkgs/hyprpy.nix { };
    }
  );

  protobuf-language-server = super.callPackage ./pkgs/protobuf-language-server.nix { };

  # nixpkgs version takes forever to build all the driver versions
  nvtop-appimage =
    let
      pname = "nvtop";
      version = "3.1.0";
      src = super.fetchurl {
        url = "https://github.com/Syllo/nvtop/releases/download/${version}/${pname}-x86_64.AppImage";
        hash = "sha256-7qmNZtliJc97yZBQE9+adQZMn8VMOKkJe91j4U9GMN8=";
      };
    in
    super.appimageTools.wrapType2 {
      inherit pname version src;
    };

  # this package takes an *extremely* long time to check through all the files
  catppuccin-papirus-folders = super.catppuccin-papirus-folders.overrideAttrs (
    finalAttrs: previousAttrs: {
      doCheck = false;
    }
  );
}
