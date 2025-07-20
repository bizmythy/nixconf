{
  lib,
  ...
}:
{
  dirac.graphical = false;
  # override what i am already managing in home manager
  programs = {
    direnv.enable = false;
    git.enable = lib.mkForce false;
    starship.enable = false;
  };
}
