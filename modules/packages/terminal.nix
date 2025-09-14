{
  pkgs,
  inputs,
  vars,
  ...
}:

{
  # Enable zsh and make default
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  environment.systemPackages = with pkgs; [
    # coreutils rust rewrite, testing it out
    uutils-coreutils-noprefix
    # terminal tools
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
    gitea
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
    cowsay
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
    perf
    # wifi monitoring
    wavemon
    # gpu monitoring
    nvtop-appimage
    # check opencl devices
    clinfo
    # for very productive and serious work
    rust-stakeholder
    # determine type of FILEs
    file
    # exfat support
    exfatprogs
    # includes `jstest`, a tool for testing joystick inputs
    linuxConsoleTools
    # disk imaging/flashing
    caligula
    # command-line tool to generate, analyze, convert and manipulate colors
    pastel
    # take screenshots of colored terminal output
    termshot
    # get html of terminal output
    aha
    # lightweight terminal session recordings
    asciinema
    # silly fish swimming around
    asciiquarium-transparent
    # download files fast and in parallel
    aria2

    # ai coding agents
    nur.repos.charmbracelet.crush
    codex

    # document tools
    # latex-killer, create documents in expressive language
    typst

    # docker tools
    docker-buildx
    dive

    # go tools
    go
    gopls
    golangci-lint
    golangci-lint-langserver

    # python tools
    pyright
    uv
    ruff
    ty

    # language tools
    markdown-oxide
    shellcheck
    protobuf-language-server
    buf
    zig_0_15

    # nix tools
    nix-output-monitor
    nixfmt-rfc-style
    nurl
    manix
    nix-search-cli
    nil
    nixd
    cachix

    awscli2
    ssm-session-manager-plugin
  ];

  # https://github.com/viperML/nh
  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 10d";
    flake = vars.flakePath;
  };

  # Set up docker
  virtualisation = {
    docker = {
      enable = true;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };

      daemon.settings = {
        insecure-registries = [ "192.168.1.244:5000" ];
      };
    };
    podman = {
      enable = true;
      autoPrune.enable = true;
    };
  };

  programs._1password.enable = true;
}
