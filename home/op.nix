{
  ...
}:
{
  programs.onepassword-secrets = {
    enable = true;
    tokenFile = "/etc/opnix-token";

    secrets = {
      spotifyPlayer = {
        reference = "op://opnix/spotify-player/credential";
        path = ".config/spotify-player/clientid";
      };
    };
  };
}
