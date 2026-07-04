{
  ...
}:
{
  imports = [
    # keep-sorted start
    ./archive
    ./bat.nix
    ./btop.nix
    ./chromium.nix
    ./feh.nix
    ./firefox.nix
    ./gh.nix
    ./glow.nix
    ./helix.nix
    ./herdr
    ./lazydocker.nix
    ./lazygit.nix
    ./nvim.nix
    ./op.nix
    ./spotify-player.nix
    ./tuicr
    ./vesktop.nix
    # keep-sorted end
  ];

  # enable comma for command execution direct from nix-index search
  programs.nix-index-database.comma.enable = true;
}
