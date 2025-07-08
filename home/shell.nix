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

    msr = "zsh -c 'mask services reset && lazydocker'";
    msb = "mask services build";
    msu = "mask services up";
    gen = "mask generate";
    savelogs = "mask services savelogs";
    diraclocalserver = "ssh diraclocalserver -t 'nu'"; # connect and use nushell
  };

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

    nushell =
      let
        nuscripts = pkgs.fetchFromGitHub {
          owner = "nushell";
          repo = "nu_scripts";
          rev = "6faa666e558bc53be9bf8836d4d1734926fa84d2";
          hash = "sha256-BPuWq1ld2eqSvugOCNToEA9+Q6q94TfI7OjkLnBS+oY=";
        };

        formatInput = input: "use ${nuscripts}/custom-completions/${input}/${input}-completions.nu *";
        formatCompletions = inputs: (builtins.concatStringsSep "\n" (map formatInput inputs)) + "\n";
      in
      {
        enable = true;
        environmentVariables = mySessionVariables // {
          AWS_PROFILE = "dev";
        };
        shellAliases = myShellAliases;
        extraConfig =
          formatCompletions [
            "curl"
            "docker"
            "less"
            "make"
            "man"
            "op"
            "tar"
          ]
          + ''

            source ${./utils.nu};
            use ${nuscripts}/modules/jc/

            $env.config.show_banner = false
            $env.config.buffer_editor = "${vars.defaults.termEditor}"

            nerdfetch
          '';
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
