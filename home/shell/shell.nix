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
      syntaxHighlighting.enable = true;
      autosuggestion.enable = true;
      initExtra = ''
        # Load environment variables from secrets.env file
        if [ -f "/home/drew/.config/secrets.env" ]; then
          while IFS='=' read -r key value || [ -n "$key" ]; do
            # Export the variable
            export "$key=$value"
          done < "/home/drew/.config/secrets.env"
        else
          echo "Warning: /home/drew/.config/secrets.env file not found"
        fi
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

    direnv = {
      enable = true;
      nix-direnv.enable = true;

      enableBashIntegration = true;
      enableZshIntegration = true;
      enableNushellIntegration = true;

      config = {
        whitelist = {
          prefix = [
            "~/buildos-web"
            "~/dirac"
          ];
        };
      };
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
        format = "$all$shell$character";
        aws = {
          disabled = true;
        };
        character = {
          success_symbol = "[➜](bold green)";
          error_symbol = "[➜](bold red)";
        };
        # configure shell-specific icons
        shell = {
          disabled = false;
          format = "$indicator($style)";
          bash_indicator = "\\$ ";
          zsh_indicator = "% ";
          nu_indicator = "";
          unknown_indicator = "? ";
          style = "white bold";
        };
      };
    };
  };
}
