{
  lib,
  osConfig,
  vars,
  ...
}:
{
  programs.vesktop = lib.mkIf (vars.isPersonal osConfig) {
    enable = true;
  };
}
