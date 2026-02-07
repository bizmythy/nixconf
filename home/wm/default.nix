{
  vars,
  ...
}:

{
  imports = [
    ./waybar
    ./hyprland.nix
    ./hyprlock.nix
    ./hyprlaunch
    ./hyprmonitor
    ./hyprpaper.nix
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
    HYPRSHOT_DIR = "${vars.home}/Pictures/screenshots";
  };
}
