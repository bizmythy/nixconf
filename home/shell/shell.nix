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

    # dirac
    awsl = "zsh -c 'sudo rm -rf ~/.aws/cli ~/.aws/sso && aws sso login --profile dirac-dev'";
  };
  mySessionVariables = {
    EDITOR = "nvim";
    FLAKE = vars.flakePath;

    # dirac
    AWS_PROFILE = "dirac-dev";
    COGNITO_USER_EMAIL_DEV_INTERNAL = "drew@diracinc.com";
    TEAM_ID_DEV = "dirac";
  };
  nushellCatppuccin = pkgs.fetchFromGitHub {
    owner = "nik-rev";
    repo = "catppuccin-nushell";
    rev = "82c31124b39294c722f5853cf94edc01ad5ddf34";
    hash = "sha256-O95OrdF9UA5xid1UlXzqrgZqw3fBpTChUDmyExmD2i4=";
  };
in
{
  home = {
    shellAliases = myShellAliases;
    sessionVariables = mySessionVariables;
  };
  programs = {
    zsh = {
      enable = true;
      initExtra = ''
        source /home/drew/.config/secrets
      '';
    };

    bash.enable = true;

    nushell = {
      enable = true;
      environmentVariables = mySessionVariables;
      shellAliases = myShellAliases;
      extraConfig =
        builtins.readFile "${nushellCatppuccin}/themes/catppuccin_mocha.nu" + builtins.readFile ./config.nu;
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

    starship = {
      enable = true;
      settings = {
        aws = {
          disabled = true;
        };
      };
    };
  };
}
