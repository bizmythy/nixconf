{
  lib,
  pkgs,
  ...
}:
{
  projectRootFile = "flake.nix";
  programs.nixfmt.enable = true;
  programs.jsonfmt.enable = true;
  programs.shellcheck.enable = true;
  programs.keep-sorted.enable = true;
  programs.ruff.enable = true;
  programs.toml-sort.enable = true;

  settings.formatter.nufmt = {
    command = lib.getExe pkgs.topiary-nushell;
    includes = [ "*.nu" ];
  };
}
