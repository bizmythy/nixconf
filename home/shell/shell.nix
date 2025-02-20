{
  config,
  pkgs,
  inputs,
  vars,
  ...
}:
let
  myShellAliases = {
    lg = "lazygit";
    ld = "lazydocker";
    nhos = "nh os switch";
    cdb = "cd /home/drew/dirac/buildos-web";
    edit = "zsh -c '(&>/dev/null cursor . &)'";
  };
  mySessionVariables = {
    EDITOR = "nvim";
    FLAKE = vars.flakePath;
  };
in
{
  home = {
    shellAliases = myShellAliases;
    sessionVariables = mySessionVariables;
  };
  programs = {
    zsh.enable = true;

    bash.enable = true;

    nushell = {
      enable = true;
      environmentVariables = mySessionVariables;
      shellAliases = myShellAliases;
    };

    eza = {
      enable = true;
      icons = "auto";
      enableNushellIntegration = false;
      enableZshIntegration = true;
      enableBashIntegration = true;
    };


    atuin = {
      enable = true;
      enableZshIntegration = true;
      enableBashIntegration = true;
      enableNushellIntegration = true;
      settings = {
        auto_sync = true;
        enter_accept = true;
        style = "compact";
        inline_height = 20;
        filter_mode_shell_up_key_binding = "session";
      };
    };

    starship.enable = true;
  };
}
