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
in
{
  # Enable zsh and make default
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
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
