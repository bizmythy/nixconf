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
      iconExtension,
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
          name = "${name}.${iconExtension}";
          url = faviconURL url;
          hash = iconHash;
        };
      }
      // (if categories != null then { inherit categories; } else { })
    );

  # use icon.horse to get the favicons
  faviconURL = url: "https://icon.horse/icon/${url}";

  webApps = map makeWebApp [
    {
      name = "Linear";
      url = "linear.app";
      iconExtension = "svg";
      iconHash = "sha256-VomIEAIlO1k7f3ZSFcMzyAbLJEDJ2e/aj7AIN3fsjr0=";
    }
  ];
in
{
  environment.systemPackages = lib.mkAfter webApps;
}
