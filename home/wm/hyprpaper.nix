{
  pkgs,
  ...
}:

let
  wallpaper = pkgs.fetchurl {
    url = "https://filedn.com/l0xkAHTdfcEJNc2OW7dfBny/purple_crystals.jpg";
    sha256 = "0fyrzlbx6ii9nzpn2vpl45vdq9hh87af18d3sjpvv66cbsc9vwga";
  };
in
{
  services.hyprpaper = {
    enable = true;
    settings = {
      wallpaper = [
        {
          monitor = "";
          path = wallpaper.outPath;
          # fit_mode = "cover";
        }
      ];
      splash = false;
    };
  };
}
