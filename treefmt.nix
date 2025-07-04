{
  pkgs,
  ...
}:
{
  projectRootFile = "flake.nix";
  programs.nixfmt.enable = true;
  # buggy as of right now
  # programs.nufmt.enable = true;
}
