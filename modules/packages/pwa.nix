{
  pkgs,
  lib,
  ...
}:
let
  # modified from https://github.com/bjornfor/nixos-config/blob/master/lib/default.nix
  makeSimpleWebApp =
    {
      name,
      url,
      icon ? null,
      comment ? null,
      desktopName ? comment,
      categories ? null,
      browser ? "chromium-browser",
      darkMode ? true,
    }:
    pkgs.makeDesktopItem (
      let
        darkModeArgs = if darkMode then "--force-dark-mode --enable-features=WebUIDarkMode " else "";
      in
      {
        inherit name;
        exec = "${browser} --ozone-platform-hint=auto ${darkModeArgs}--app=https://${url}/";
        extraEntries = ''
          StartupWMClass=${name} ${url}
        '';
      }
      // (if icon != null then { inherit icon; } else { })
      // (if comment != null then { inherit comment; } else { })
      // (if desktopName != null then { inherit desktopName; } else { })
      // (if categories != null then { inherit categories; } else { })
    );

  webApps = map makeSimpleWebApp [
    {
      name = "linear";
      url = "linear.app";
      comment = "Linear";
    }
  ];
in
{
  environment.systemPackages = lib.mkAfter webApps;
}
