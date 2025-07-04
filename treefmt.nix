{
  pkgs,
  ...
}:
{
  projectRootFile = "flake.nix";
  programs.nixfmt.enable = true;
  programs.nufmt.enable = true;
}
