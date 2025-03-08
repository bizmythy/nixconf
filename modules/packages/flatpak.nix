{
  ...
}:

{
  services.flatpak = {
    enable = true;
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };

    overrides = {
      global = {
        # Force Wayland by default
        Context.sockets = [
          "wayland"
          "!x11"
          "!fallback-x11"
        ];

        Environment = {
          # Fix un-themed cursor in some Wayland apps
          XCURSOR_PATH = "/run/host/user-share/icons:/run/host/share/icons";

          # Force correct theme for some GTK apps
          GTK_THEME = "Adwaita:dark";
        };
      };

      "org.signal.Signal".Environment = {
        SIGNAL_PASSWORD_STORE = "kwallet";
      };
    };

    # flatpak packages
    packages = [
      "com.obsproject.Studio"
      "org.signal.Signal"
      "com.discordapp.Discord"
      "com.github.tchx84.Flatseal"
      "us.zoom.Zoom"
    ];
  };
}
