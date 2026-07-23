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
    ./jujutsu.nix
    ./lazydocker.nix
    ./lazygit.nix
    ./nvim.nix
    ./op.nix
    ./spotify-player.nix
    ./tuicr
    ./vesktop.nix
    # keep-sorted end
  ];

  programs = {
    # enable comma for command execution direct from nix-index search
    nix-index-database.comma.enable = true;

    # Keep Bash minimal for testing.
    nix-index.enableBashIntegration = false;
  };
}
