{
  lib,
  pkgs,
  vars,
  ...
}:
let
  substitutersConfig = builtins.fromJSON (builtins.readFile ../../substituters_config.json);
in
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

  # Manage the official multi-user Nix installation through nix-darwin.
  nix = {
    enable = true;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        vars.user
        "@admin"
      ];
    }
    // lib.getAttrs [
      "extra-substituters"
      "extra-trusted-substituters"
      "extra-trusted-public-keys"
    ] substitutersConfig;
  };
}
