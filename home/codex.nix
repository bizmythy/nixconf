{
  pkgs,
  inputs,
  ...
}:

{
  programs.codex = {
    enable = true;
    package = inputs.nix-ai-tools.packages.${pkgs.system}.codex;
    settings = {
      sandbox_mode = "danger-full-access";
    };
  };
}
