{
  pkgs,
  vars,
  ...
}:
let
  mySessionVariables = {
    EDITOR = vars.defaults.termEditor;
    VISUAL = vars.defaults.editor;
    BROWSER = vars.defaults.browser;
    NH_NO_CHECKS = 1;
    NIXPKGS_ALLOW_UNFREE = 1;
  };
  myShellAliases = {
    cdn = "cd ${vars.flakePath}";

    zed = "zeditor";
    e = "${vars.defaults.editor} .";
    code = "zsh -c '(&>/dev/null cursor . &)'";

    lg = "lazygit";
    ld = "lazydocker";
    hmclean = "fd '${vars.hmBackupFileExtension}' ~ -u -x rm";
    dcd = "docker compose down";
    "??" = "gh copilot suggest -t shell";

    # dirac
    cdb = "cd ${vars.home}/dirac/buildos-web";
    alf = "zsh -c 'sudo rm -rf ${vars.home}/.aws/cli ${vars.home}/.aws/sso && aws sso login'";
    al = "aws sso login";

    mts = "make test-shell";
    mcr = "make compose-reset";
    mcs = "make compose";
  };

  nuscripts = pkgs.fetchFromGitHub {
    owner = "nushell";
    repo = "nu_scripts";
    rev = "861a99779d31010ba907e4d6aaf7b1629b9eb775";
    hash = "sha256-L/ySTOTGijpu+6Bncg+Rn7MBd/R5liSSPLlfoQvg7ps=";
  };
  formatCompletions =
    inputs:
    let
      formatInput = input: "use ${nuscripts}/custom-completions/${input}/${input}-completions.nu *";
      formattedInputs = map formatInput inputs;
    in
    builtins.concatStringsSep "\n" formattedInputs;

  nushellConfig =
    ''
      source ${./utils.nu};
      use ${nuscripts}/modules/jc/

      $env.config.show_banner = false
      $env.config.buffer_editor = "${vars.defaults.termEditor}"
    ''
    + formatCompletions [
      "curl"
      "less"
      "make"
      "man"
      "op"
      "tar"
    ];
in
{
  home = {
    shellAliases = myShellAliases;
    sessionVariables = mySessionVariables;
    sessionPath = [
      "${vars.home}/.local/bin"
    ];
  };
  programs = {
    zsh = {
      enable = true;
      syntaxHighlighting.enable = true;
      autosuggestion.enable = true;
      initContent = ''
        function y() {
         	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
         	yazi "$@" --cwd-file="$tmp"
         	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
          		builtin cd -- "$cwd"
         	fi
         	rm -f -- "$tmp"
        }
      '';
    };

    bash.enable = true;

    nushell = {
      enable = true;
      environmentVariables = mySessionVariables // {
        AWS_PROFILE = "dev";
      };
      shellAliases = myShellAliases;
      extraConfig = nushellConfig;
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
      enableBashIntegration = false;
    };

    atuin = {
      enable = true;
      enableZshIntegration = true;
      enableNushellIntegration = true;
      enableBashIntegration = false;
      settings = {
        auto_sync = true;
        enter_accept = true;
        style = "compact";
        inline_height = 20;
        filter_mode_shell_up_key_binding = "session";
      };
    };

    yazi = {
      enable = true;
      enableZshIntegration = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
      enableBashIntegration = true;
    };

    fzf = {
      enable = true;
      enableZshIntegration = false;
      enableFishIntegration = false;
      enableBashIntegration = false;
    };

    starship = {
      enable = true;
      enableZshIntegration = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
      enableBashIntegration = false;
      settings = {
        aws.disabled = true;
        git_status.disabled = true;
        golang.disabled = true;
        cmake.disabled = true;
        buf.disabled = true;
        python.disabled = true;
        character = {
          success_symbol = "[➜](bold green)";
          error_symbol = "[➜](bold red)";
        };
        # configure shell-specific icons
        shell = {
          disabled = false;
          format = "$indicator($style)";
          bash_indicator = "bash ";
          zsh_indicator = "%";
          nu_indicator = "";
          unknown_indicator = "? ";
          style = "white bold";
        };
      };
    };

    zellij = {
      enable = true;

      enableZshIntegration = false;
      enableFishIntegration = false;
      enableBashIntegration = false;
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
      enableNushellIntegration = true;
      enableBashIntegration = false;
      options = [ "--cmd cd" ];
    };
  };
}
