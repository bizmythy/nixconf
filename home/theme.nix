{
  config,
  lib,
  pkgs,
  platform,
  ...
}:

let
  cursor = {
    name = "phinger-cursors-light";
    package = pkgs.phinger-cursors;
    size = 24;
  };
in
{
  fonts.fontconfig.enable = true;
}
// lib.optionalAttrs platform.isLinux {
  catppuccin = {
    enable = true;
    autoEnable = true;
    flavor = "mocha";
    mako.enable = false;
  };

  home.pointerCursor = cursor // {
    enable = true;
  };

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    gtk4.theme = config.gtk.theme;
    cursorTheme = cursor;
  };

  qt = {
    enable = true;
    platformTheme.name = "kvantum";
    style.name = "kvantum";

    # Fixes for Kvantum and the icon theme in KDE applications.
    kde.settings.kdeglobals = {
      UiSettings.ColorScheme = "Kvantum";
      Icons.Theme = "Papirus-Dark";
    };
  };
}
