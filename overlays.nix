self: super: {
  python3Packages = super.python3Packages.overrideScope (
    python-self: python-super: {
      hyprpy = super.callPackage ./pkgs/hyprpy.nix { };
    }
  );

  protobuf-language-server = super.callPackage ./pkgs/protobuf-language-server.nix { };

  codex = super.callPackage ./pkgs/codex.nix { };

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

  # _1password-gui = super._1password-gui.overrideAttrs (
  #   finalAttrs: previousAttrs: {
  #     preFixup = ''
  #       # makeWrapper defaults to makeBinaryWrapper due to wrapGAppsHook
  #       # but we need a shell wrapper specifically for `NIXOS_OZONE_WL`.
  #       # Electron is trying to open udev via dlopen()
  #       # and for some reason that doesn't seem to be impacted from the rpath.
  #       # Adding udev to LD_LIBRARY_PATH fixes that.
  #       # Make xdg-open overrideable at runtime.
  #       makeShellWrapper $out/share/1password/1password $out/bin/1password \
  #         "''${gappsWrapperArgs[@]}" \
  #         --suffix PATH : ${super.lib.makeBinPath [ super.xdg-utils ]} \
  #         --prefix LD_LIBRARY_PATH : ${super.lib.makeLibraryPath [ super.udev ]}
  #         # Currently half broken on wayland (e.g. no copy functionality)
  #         # See: https://github.com/NixOS/nixpkgs/pull/232718#issuecomment-1582123406
  #         # Remove this comment when upstream fixes:
  #         # https://1password.community/discussion/comment/624011/#Comment_624011
  #         #--add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"
  #     '';
  #   }
  # );
}
