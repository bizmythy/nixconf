{ inputs }:

self: super:
let
  hyprlandPackages = import ./pkgs/hyprland-upstream.nix {
    pkgs = super;
    inherit inputs;
  };
in
{
  aquamarine = hyprlandPackages.aquamarine;
  hyprland = hyprlandPackages.hyprland;
  xdg-desktop-portal-hyprland = hyprlandPackages.xdg-desktop-portal-hyprland;

  # Use rocmPackages from nixpkgs-stable to avoid crashes with unstable
  rocmPackages =
    inputs.nixpkgs-stable.legacyPackages.${super.stdenv.hostPlatform.system}.rocmPackages;
  python3Packages = super.python3Packages.overrideScope (
    python-self: python-super: {
      hyprpy = super.callPackage ./pkgs/hyprpy.nix { };
    }
  );

  protobuf-language-server = super.callPackage ./pkgs/protobuf-language-server.nix { };
  manix = inputs.manix.packages.${super.stdenv.hostPlatform.system}.manix;
  t3code = inputs.t3code.packages.${super.stdenv.hostPlatform.system}.default;
  # Upstream currently hard-codes macOS pbcopy/pbpaste; use Wayland wl-clipboard.
  tdx = inputs.tdx.packages.${super.stdenv.hostPlatform.system}.default.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [ ./pkgs/tdx-clipboard-linux.patch ];
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ super.makeWrapper ];
    postInstall = (oldAttrs.postInstall or "") + ''
      wrapProgram $out/bin/tdx \
        --prefix PATH : ${super.lib.makeBinPath [ super.wl-clipboard ]}
    '';
  });
  xhisper-local = super.callPackage ./pkgs/xhisper-local.nix {
    whisperCpp = super.whisper-cpp;
  };

  nu-plugin-toon = super.callPackage ./pkgs/nu_plugin_toon.nix { };
  topiary-nushell = super.callPackage ./pkgs/topiary-nushell.nix { };
  linear-cli = super.callPackage ./pkgs/linear-cli.nix { };

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
