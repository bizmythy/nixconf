{
  pkgs,
  vars,
  ...
}:
{
  imports = [
    ./programs/archive
    ./programs/bat.nix
    ./programs/btop.nix
    ./programs/gh.nix
    ./programs/glow.nix
    ./programs/helix.nix
    ./programs/lazygit.nix
    ./programs/nvim.nix
    ./programs/tuicr
    ./shell.nix
    ./ssh-git.nix
  ];

  home = {
    stateVersion = "24.11";
    sessionPath = [ "${vars.home}/.local/bin" ];
    packages = with pkgs; [
      cht-sh
      curl
      fastfetch
      fd
      file
      jq
      just
      manix
      nerdfetch
      nix-output-monitor
      nixd
      nixfmt
      nurl
      rclone
      ripgrep
      rsync
      tree
      unzip
      wget
      xh
      yq
      zip
      zstd
    ];
  };

  programs.home-manager.enable = true;
  programs.nix-index-database.comma.enable = true;

  catppuccin = {
    enable = true;
    autoEnable = true;
    flavor = "mocha";
  };
}
