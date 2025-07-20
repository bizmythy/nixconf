{
  lib,
  ...
}:
{
  # don't get the default graphical packages, i will manage them myself
  dirac.graphical = false;

  # override what i am already managing in home manager
  programs = {
    direnv.enable = false;
    git.enable = lib.mkForce false;
    starship.enable = false;
  };

  # don't start twingate at boot, will be started manually when desired
  systemd.services."twingate".wantedBy = lib.mkForce [ ];
}
