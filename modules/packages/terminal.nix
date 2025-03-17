{
  lib,
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
    yazi
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

    # language tools
    go
    gopls
    nil
    nixd
    markdown-oxide
    shellcheck
    protobuf-language-server
    dive

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
