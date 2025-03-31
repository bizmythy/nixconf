{
  pkgs,
  lib,
  ...
}:
let
  # modified from https://github.com/bjornfor/nixos-config/blob/master/lib/default.nix
  makeWebApp =
    {
      name,
      url,
      iconHash,
      startupWMClass ? "${name} ${url}",
      categories ? null,
      browser ? "chromium-browser",
      darkMode ? true,
    }:
    pkgs.makeDesktopItem (
      let
        darkModeArgs = if darkMode then "--force-dark-mode --enable-features=WebUIDarkMode " else "";
        exec = "${browser} --ozone-platform-hint=auto ${darkModeArgs}--app=https://${url}/";
      in
      {
        inherit name startupWMClass exec;
        comment = name;
        desktopName = name;
        icon = pkgs.fetchurl {
          name = "${name}.ico";
          url = "${url}/favicon.ico";
          hash = iconHash;
        };
      }
      // (if categories != null then { inherit categories; } else { })
    );

  webApps = map makeWebApp [
    {
      name = "Linear";
      url = "linear.app";
      iconHash = "sha256-D/X3IJT7uNHC0lANroJhCM7eyo4BnMc9M9H44sCbij8=";
    }
    {
      name = "GitHub";
      url = "github.com";
      iconHash = "sha256-LuQyN9GWEAIQ8Xhue3O1fNFA9gE8Byxw29/9npvGlfg=";
    }
  ];
in
{
  environment.systemPackages = lib.mkAfter webApps;
}
