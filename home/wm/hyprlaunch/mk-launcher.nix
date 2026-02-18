{
  pkgs,
  lib,
}:
let
  hyprlaunch = import ./package.nix { inherit pkgs; };
in
{
  name ? "hyprlaunch-run",
  directives,
  restore ? false,
}:
let
  configFile = pkgs.writeText "${name}-config.json" (builtins.toJSON directives);
  restoreFlag = lib.optionalString restore " --restore";
in
pkgs.writeShellApplication {
  inherit name;
  text = ''
    ${lib.getExe hyprlaunch} ${configFile}${restoreFlag}
  '';
}
