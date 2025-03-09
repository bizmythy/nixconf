{
  lib,
  pkgs,
  ...
}:

let
  fontFamily = "JetBrainsMono Nerd Font";
  fontSize = 12;
  backgroundOpacity = 0.9;
  # https://github.com/ghostty-org/ghostty/discussions/3167#discussioncomment-12434378
  ghostty-cursor-patched = pkgs.ghostty.override {
    wrapGAppsHook4 = pkgs.wrapGAppsNoGuiHook.override {
      isGraphical = true;
      gtk3 =
        (pkgs.__splicedPackages.gtk4.override {
          wayland-protocols = pkgs.wayland-protocols.overrideAttrs (o: rec {
            version = "1.41";
            src = pkgs.fetchurl {
              url = "https://gitlab.freedesktop.org/wayland/${o.pname}/-/releases/${version}/downloads/${o.pname}-${version}.tar.xz";
              hash = "sha256-J4a2sbeZZeMT8sKJwSB1ue1wDUGESBDFGv2hDuMpV2s=";
            };
          });
        }).overrideAttrs
          (o: rec {
            version = "4.17.6";
            src = pkgs.fetchurl {
              url = "mirror://gnome/sources/gtk/${lib.versions.majorMinor version}/gtk-${version}.tar.xz";
              hash = "sha256-366boSY/hK+oOklNsu0UxzksZ4QLZzC/om63n94eE6E=";
            };
            postFixup = ''
              demos=(gtk4-demo gtk4-demo-application gtk4-widget-factory)

              for program in ''${demos[@]}; do
                wrapProgram $dev/bin/$program \
                  --prefix XDG_DATA_DIRS : "$GSETTINGS_SCHEMAS_PATH:$out/share/gsettings-schemas/${o.pname}-${version}"
              done

              # Cannot be in postInstall, otherwise _multioutDocs hook in preFixup will move right back.
              moveToOutput "share/doc" "$devdoc"
            '';
          });
    };
  };
in
{
  programs.alacritty = {
    enable = true;
    settings = {
      window = {
        opacity = backgroundOpacity;
      };

      scrolling.history = 10000;

      selection.save_to_clipboard = true;

      terminal.shell = {
        program = "zsh";
        args = [
          "-c"
          "nerdfetch && zsh"
        ];
      };

      font = {
        normal = {
          family = fontFamily;
          style = "Regular";
        };
        bold = {
          family = fontFamily;
          style = "Bold";
        };
        italic = {
          family = fontFamily;
          style = "Italic";
        };
        bold_italic = {
          family = fontFamily;
          style = "Bold Italic";
        };
        size = fontSize;
      };
    };
  };

  programs.ghostty = {
    enable = true;
    settings = {
      font-family = fontFamily;
      font-size = fontSize;
      background-opacity = backgroundOpacity;
      copy-on-select = true;
    };
    enableBashIntegration = true;
    enableZshIntegration = true;
    package = ghostty-cursor-patched;
  };
}
