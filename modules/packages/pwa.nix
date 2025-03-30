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
    }:
    pkgs.makeDesktopItem (
      {
        inherit name;
        exec = "${browser} --app=https://${url}/";
        extraEntries = ''
          StartupWMClass=${name} ${url}
        '';
      }
      // (if icon != null then { inherit icon; } else { })
      // (if comment != null then { inherit comment; } else { })
      // (if desktopName != null then { inherit desktopName; } else { })
      // (if categories != null then { inherit categories; } else { })
    );
in
{

}
