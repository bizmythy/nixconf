self: super: {
  python3Packages = super.python3Packages.overrideScope (
    python-self: python-super: {
      hyprpy = super.callPackage ./pkgs/hyprpy.nix { };
    }
  );

  protobuf-language-server = super.callPackage ./pkgs/protobuf-language-server.nix { };

  codex = super.callPackage ./pkgs/codex.nix { };

  nu-plugin-toon = super.callPackage ./pkgs/nu_plugin-toon.nix { };

  amd-ctk = super.callPackage ./pkgs/amd-ctk.nix { };
  amd-container-runtime = super.callPackage ./pkgs/amd-container-runtime.nix { };

  # nixpkgs version takes forever to build all the driver versions
  nvtop-appimage =
    let
      pname = "nvtop";
      version = "3.2.0";
      src = super.fetchurl {
        url = "https://github.com/Syllo/nvtop/releases/download/3.2.0/${pname}-${version}-x86_64.AppImage";
        hash = "sha256-M8VPtwJfQ6IT246YMIhg1ADbM0mmH8k4L+RzbH0lgMQ=";
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
