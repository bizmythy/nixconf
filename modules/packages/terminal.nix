{
  pkgs,
  vars,
  ...
}:

let
  protobuf-language-server = pkgs.buildGoModule {
    pname = "protobuf-language-server";
    version = "0.1.0";
    src = pkgs.fetchFromGitHub {
      owner = "lasorda";
      repo = "protobuf-language-server";
      rev = "8e82adc0984f3c7a4d5179ad19fd86a034659e76";
      hash = "sha256-R/enXn6korpZxnrDyLXfEDnCnW+OaBfgN1sW9dmcFNg=";
    };

    vendorHash = "sha256-dRria1zm5Jk7ScXh0HXeU686EmZcRrz5ZgnF0ca9aUQ=";
    doCheck = false;
  };

  # nixpkgs version takes forever to build all the driver versions
  nvtop-appimage =
    let
      pname = "nvtop";
      version = "3.1.0";
      src = pkgs.fetchurl {
        url = "https://github.com/Syllo/nvtop/releases/download/${version}/${pname}-x86_64.AppImage";
        hash = "sha256-7qmNZtliJc97yZBQE9+adQZMn8VMOKkJe91j4U9GMN8=";
      };
    in
    pkgs.appimageTools.wrapType2 {
      inherit pname version src;
    };

  openai-codex = pkgs.buildNpmPackage rec {
    pname = "codex";
    version = "0.1.2504161510"; # from codex-cli/package.json

    src = pkgs.fetchFromGitHub {
      owner = "openai";
      repo = "codex";
      rev = "b0ccca555685b1534a0028cb7bfdcad8fe2e477a";
      hash = "sha256-WTnP6HZfrMjUoUZL635cngpfvvjrA2Zvm74T2627GwA=";
    };

    sourceRoot = "${src.name}/codex-cli";

    npmDepsHash = "sha256-riVXC7T9zgUBUazH5Wq7+MjU1FepLkp9kHLSq+ZVqbs=";

    doInstallCheck = true;
    nativeInstallCheckInputs = [ pkgs.versionCheckHook ];
  };
in
{
  # Enable zsh and make default
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    # coreutils rust rewrite, testing it out
    uutils-coreutils-noprefix
    # terminal tools
    neovim
    wget
    git
    git-lfs
    ripgrep
    fd
    bat
    eza
    unzip
    btop
    htop
    hwinfo
    lshw
    gh
    lazygit
    lazydocker
    cht-sh
    nerdfetch
    fastfetch
    ffmpeg
    imagemagick
    zstd
    nmap
    traceroute
    rclone
    lsof
    jc
    dig
    jq
    yq
    tetris
    # curl replacement, http requests
    xh
    # disk usage, more intuative du
    dust
    # interactive disk usage
    dua
    # benchmarking tool
    hyperfine
    # SQL queries for files
    fselect
    # ripgrep lots of file types
    ripgrep-all
    # count ammount of code by language
    tokei
    # wikipedia search
    wiki-tui
    # modern make replacement
    just
    # self-documenting command runner
    mask
    # tui for running multiple processes
    mprocs
    # terminal presentation
    presenterm
    # find replace with confirmation
    repgrep
    # git log with tree
    serie
    # postgres (and other db) tui viewer
    rainfrog
    # scan for wifi and devices
    netscanner
    # postman from tui
    atac
    # cpu stress test/monitor
    s-tui
    # another top tool, shows lots of data
    atop
    # show network interface usage
    iftop
    # show disk bandwidth usage
    iotop
    # container process inspection
    sysdig
    # performance inspection
    linuxPackages_latest.perf
    # wifi monitoring
    wavemon
    # gpu monitoring
    nvtop-appimage
    # for very productive and serious work
    rust-stakeholder
    # determine type of FILEs
    file
    # exfat support
    exfatprogs
    # advanced docker build stuff
    docker-buildx
    # openai codex CLI for AI slop
    openai-codex

    # go tools
    go
    gopls
    golangci-lint
    golangci-lint-langserver

    # language tools
    nil
    nixd
    markdown-oxide
    shellcheck
    protobuf-language-server
    buf
    dive
    pyright
    uv

    # nix tools
    nix-output-monitor
    nixfmt-rfc-style
    nurl
    manix
    nix-search-cli
  ];

  # https://github.com/viperML/nh
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 10d";
    flake = vars.flakePath;
  };

  # Set up docker
  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = true;
      setSocketVariable = true;
    };

    # daemon.settings = {
    #   "bridge" = "none";
    # };
  };

  programs._1password.enable = true;
}
