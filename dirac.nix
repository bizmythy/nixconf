{
  lib,
  vars,
  ...
}:
{
  # don't get the default graphical packages, i will manage them myself
  dirac.graphical = false;

  services.dirac-workspaces = {
    enable = false;
    user = vars.user;
  };

  systemd.user.services.dirac-workspacesd.environment.SSH_AUTH_SOCK = "%h/.1password/agent.sock";

  # override what i am already managing in home manager
  programs = {
    direnv.enable = false;
    git.enable = lib.mkForce false;
    starship.enable = false;
  };

  # don't start twingate at boot, will be started manually when desired
  systemd.services."twingate".wantedBy = lib.mkForce [ ];
}
