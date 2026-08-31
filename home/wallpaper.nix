{
  lib,
  pkgs,
  platform,
  ...
}:

let
  wallpaper = pkgs.fetchurl {
    url = "https://filedn.com/l0xkAHTdfcEJNc2OW7dfBny/purple_crystals.jpg";
    sha256 = "0fyrzlbx6ii9nzpn2vpl45vdq9hh87af18d3sjpvv66cbsc9vwga";
  };
in
{
  services.hyprpaper = lib.mkIf platform.isLinux {
    enable = true;
    settings = {
      wallpaper = [
        {
          monitor = "";
          path = wallpaper.outPath;
        }
      ];
      splash = false;
    };
  };

  home.activation = lib.mkIf platform.isDarwin {
    setWallpaper = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run /usr/bin/osascript -e 'tell application "System Events" to tell every desktop to set picture to "${wallpaper}"'
    '';
  };
}
