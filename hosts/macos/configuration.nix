{
  pkgs,
  vars,
  ...
}:
{
  networking.hostName = "macos";

  system = {
    primaryUser = vars.user;
    stateVersion = 7;
  };

  users.users.${vars.user} = {
    home = vars.home;
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;

  # Determinate owns the Nix daemon and its settings.
  nix.enable = false;
}
