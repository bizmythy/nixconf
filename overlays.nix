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

  # Bump claude-code ahead of the version pinned in the llm-agents.nix input,
  # which lags Anthropic's `/latest` release pointer. Override the upstream
  # package's version + binary src so we get the newest build (needed for new
  # model availability, e.g. Sonnet 5). Remove this once llm-agents catches up.
  #
  # hiPrio: the dirac module also installs claude-code (from the same
  # llm-agents input, via lib.mkBefore) at the pinned version, so both land in
  # environment.systemPackages. Without a priority bump that older build would
  # win the /bin/claude collision. hiPrio makes this newer one win.
  claude-code =
    let
      version = "2.1.197";
      hashes = {
        x86_64-linux = "sha256-9U5py8ibLaYaQVcAr3/1KhR+hiUX1PGw7s92hEjPf4M=";
        aarch64-linux = "sha256-+0hHPEZ8J2Fax5mnVPTvC2jDY+RZbO+7WcOBXVGgzIo=";
        x86_64-darwin = "sha256-XopXzHqSN38HRPpMeRkc+T1LJsecuRmwekB1Ef7RviY=";
        aarch64-darwin = "sha256-jMDE0eTrHco7DMkqsC7jUF3nZOAj+MkBdhwWe3IEH7g=";
      };
      platformMap = {
        x86_64-linux = "linux-x64";
        aarch64-linux = "linux-arm64";
        x86_64-darwin = "darwin-x64";
        aarch64-darwin = "darwin-arm64";
      };
      system = super.stdenv.hostPlatform.system;
    in
    super.lib.hiPrio (
      inputs.llm-agents.packages.${system}.claude-code.overrideAttrs (_: {
        inherit version;
        src = super.fetchurl {
          url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/${version}/${platformMap.${system}}/claude";
          hash = hashes.${system};
        };
      })
    );

  protobuf-language-server = super.callPackage ./pkgs/protobuf-language-server.nix { };
  herdr-keybinds = super.callPackage ./home/programs/herdr/keybinds-plugin/package.nix { };
  lg-herdr-watch =
    super.runCommand "lg-herdr-watch-0.1.0"
      {
        meta = with super.lib; {
          description = "Restart lazygit when the focused Herdr workspace changes";
          license = licenses.mit;
          platforms = platforms.linux;
          mainProgram = "lg-herdr-watch";
        };
      }
      ''
        mkdir -p "$out/bin"
        ln -s "${self.herdr-keybinds}/bin/lg-herdr-watch" "$out/bin/lg-herdr-watch"
      '';
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
