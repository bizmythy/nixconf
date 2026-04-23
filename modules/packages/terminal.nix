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

  environment.systemPackages =
    let
      nixSourcced = with pkgs; [
        nushell
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
        unzip # unzip .zip
        zip # manage .zip
        _7zz # cli 7zip
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
        imagemagick # image conversion
        ghostscript # pdf reading for image conversion
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
        xh # curl replacement, http requests
        dust # disk usage, more intuative du
        dua # interactive disk usage
        hyperfine # benchmarking tool
        fselect # SQL queries for files
        ripgrep-all # ripgrep lots of file types
        tokei # count ammount of code by language
        wiki-tui # wikipedia search
        just # modern make replacement
        mask # self-documenting command runner
        mprocs # tui for running multiple processes
        presenterm # terminal presentation
        repgrep # find replace with confirmation
        serie # git log with tree
        rainfrog # postgres (and other db) tui viewer
        netscanner # scan for wifi and devices
        atac # postman from tui
        s-tui # cpu stress test/monitor
        atop # another top tool, shows lots of data
        iftop # show network interface usage
        iotop # show disk bandwidth usage
        sysdig # container process inspection
        perf # performance inspection
        wavemon # wifi monitoring
        nvtop-appimage # gpu monitoring
        clinfo # check opencl devices
        rust-stakeholder # for very productive and serious work
        file # determine type of FILEs
        exfatprogs # exfat support
        linuxConsoleTools # includes `jstest`, a tool for testing joystick inputs
        caligula # disk imaging/flashing
        pastel # command-line tool to generate, analyze, convert and manipulate colors
        termshot # take screenshots of colored terminal output
        aha # get html of terminal output
        asciinema # lightweight terminal session recordings
        asciiquarium-transparent # silly fish swimming around
        aria2 # download files fast and in parallel
        yt-dlp # dowload internet video
        xxd # hex/binary viewing
        archivemount # mounting tar archives
        presenterm # terminal presentations
        screen # run commands in background
        (aspellWithDicts (ps: with ps; [ en ])) # spell check text files

        graphite-cli

        # document tools
        typst # latex-killer, create documents in expressive language

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
        rustc
        cargo
        rustfmt

        # nix tools
        nix-output-monitor
        nixfmt
        nurl
        manix
        nix-search-cli
        nil
        nixd
        cachix

        # ssm-session-manager-plugin
      ];

      aiTools = with inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}; [
        claude-code
        # codex
        # gemini-cli
      ];
    in
    (nixSourcced ++ aiTools);

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
