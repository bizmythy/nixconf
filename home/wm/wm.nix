{
  pkgs,
  ...
}:

{
  imports = [
    ./bar/waybar.nix
    ./hypr/hyprland.nix
  ];

  programs.fuzzel = {
    enable = true;
    settings = {
      "border" = {
        "width" = 3;
      };
    };
  };
  services.swaync = {
    enable = true;
  };

  dconf = {
    enable = true;
    settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };

  home.sessionVariables = {
    HYPRSHOT_DIR = "/home/drew/Pictures/screenshots";
  };

  services.hyprpaper =
    let
      wallpaper = pkgs.fetchurl {
        url = "https://filedn.com/l0xkAHTdfcEJNc2OW7dfBny/purple_crystals.jpg";
        sha256 = "0fyrzlbx6ii9nzpn2vpl45vdq9hh87af18d3sjpvv66cbsc9vwga";
      };
    in
    {
      enable = true;
      settings = {
        preload = wallpaper.outPath;
        wallpaper = " , ${wallpaper.outPath}";
      };
    };

}
