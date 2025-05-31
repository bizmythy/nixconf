{
  pkgs,
  osConfig,
}:
{
  # spotify TUI player
  spotify-player = {
    enable = true;
    settings = {
      # fetch the client ID using 1Password
      client_id_command = {
        command = "op";
        args = [
          "--account"
          "L23KMYOBNVHLPGSIPDX7BAQ5LA"
          "read"
          "op://smfpz5gfxgz5meqdqachl7lqw4/spotify-player/credential"
        ];
      };

      device.name = "${osConfig.networking.hostName}-spotify-player";

      # weird values needed to make album art square
      cover_img_width = 9;
      cover_img_length = 20;

      border_type = "Rounded";
      layout = {
        playback_window_position = "Bottom";
        playback_window_height = 10;
      };
    };
    actions = [
      {
        action = "ToggleLiked";
        key_sequence = "C-l";
      }
      {
        action = "AddToLibrary";
        key_sequence = "C-a";
      }
      {
        action = "Follow";
        key_sequence = "C-f";
      }
    ];
    keymaps = [
      {
        command = "PreviousPage";
        key_sequence = "esc";
      }
      {
        command = "ClosePopup";
        key_sequence = "q";
      }
      {
        command = "Repeat";
        key_sequence = "R";
      }
      {
        command = "Shuffle";
        key_sequence = "S";
      }
      {
        command = "Quit";
        key_sequence = "C-c";
      }
      {
        command = "SeekForward";
        key_sequence = "L";
      }
      {
        command = "SeekBackward";
        key_sequence = "H";
      }
      {
        command = "PageSelectPreviousOrScrollUp";
        key_sequence = "C-u";
      }
      {
        command = "PageSelectNextOrScrollDown";
        key_sequence = "C-d";
      }
      {
        command = "LikedTrackPage";
        key_sequence = "g o";
      }
    ];
  };

  # create desktop shortcut for launching
  xdg.desktopEntries.spotify-player =
    let
      ghostty-shaders = pkgs.fetchFromGitHub {
        owner = "hackr-sh";
        repo = "ghostty-shaders";
        rev = "a17573fb254e618f92a75afe80faa31fd5e09d6f";
        hash = "sha256-p0speO5BtLZZwGeuRvBFETnHspDYg2r5Uiu0yeqj1iE=";
      };
    in
    {
      name = "spotify-player";
      exec = "ghostty --custom-shader=${ghostty-shaders}/bloom.glsl -e spotify_player";
      terminal = false;
      type = "Application";
      categories = [
        "Audio"
        "Music"
      ];
    };
}
