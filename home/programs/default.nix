{
  ...
}:
{
  imports = [
    # keep-sorted start
    ./bat.nix
    ./btop.nix
    ./chromium.nix
    ./feh.nix
    ./firefox.nix
    ./gh.nix
    ./helix.nix
    ./lazydocker.nix
    ./lazygit.nix
    ./nvim.nix
    ./op.nix
    ./spotify-player.nix
    ./vesktop.nix
    # keep-sorted end
  ];

  # enable comma for command execution direct from nix-index search
  programs.nix-index-database.comma.enable = true;
}
