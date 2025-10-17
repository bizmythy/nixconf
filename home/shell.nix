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
    PAGER = "nvimpager";
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
    msu = "zsh -c 'mask services build && mask services up && lazydocker'";
    mtix = "mask start-ticket";
    msb = "mask services build";
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
          rev = "ec945380be3981522f9bb55e764a5254a908e652";
          hash = "sha256-0fw0fJSlUnT5vbBHDubqLrk3F+OU7CE15vIeU295C4w=";
        };

        formatInput = input: "use ${nuscripts}/custom-completions/${input}/${input}-completions.nu *";
        formatCompletions = inputs: (builtins.concatStringsSep "\n" (map formatInput inputs)) + "\n";
      in
      {
        enable = true;
        plugins = with pkgs.nushellPlugins; [
          # dbus # interact with dbus, broken
          formats # additional file formats
          gstat # git status for repo
          # hcl # load hashicorp config lang files, incompatible version
          # highlight # highlight source code
          # net # list network interfaces, broken
          polars # dataframe operations
          query # query sql, json, etc
          semver # work with semantic versions
          skim # integrates `sk` fuzzy finder
          # units # easily convert between common units, incompatible version
        ];
        shellAliases = myShellAliases;
        environmentVariables = mySessionVariables // {
          PROMPT_INDICATOR_VI_INSERT = "";
          AWS_PROFILE = "dev";
        };
        settings = {
          show_banner = false; # don't show startup help text
          buffer_editor = vars.defaults.termEditor;
          edit_mode = "vi"; # vi line edit mode
        };
        extraConfig =
          formatCompletions [
            "curl"
            "less"
            "make"
            "man"
            "op"
            "tar"
          ]
          + ''

            source ${./utils.nu};
            use ${nuscripts}/modules/jc/

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
