{
  ...
}:
{
  programs.onepassword-secrets = {
    enable = true;
    tokenFile = "/etc/opnix-token";

    secrets = {
      spotifyPlayer.reference = "op://Private/spotify-player/credential";
    };
  };
}
