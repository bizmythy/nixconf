{
  pkgs,
  vars,
  ...
}:
let
  genKeyFile =
    name: value:
    pkgs.writeTextFile {
      name = "${name}.pub";
      text = value;
    };

  publicKeys = {
    personalGitHub = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOjbUnES0AUVvsqNzMdCix3Qp+XRpKiS7tm6PR6u7WTY";
    diracGitHub = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIrRXpZt/U8OkMsWoft9+2JiITBsUyGVxuhZJhl+Xpm";
    diraclocalserver = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEoZXGhcmj8ZUFPWWGw3fZAd0FOCZKXnKelZKaGD9Tq4";
  };
  publicKeyFiles = builtins.mapAttrs genKeyFile publicKeys;

  onePassPath = "${vars.home}/.1password/agent.sock";
in
{
  # -------SSH CONFIGURATION-------
  # home manager version adds several extra options i do not want
  # set github.com to be dirac key by default to get private flake inputs working
  # this default is replaced in the git ssh command configuration
  home.file.".ssh/config".text = ''
    Host dirac-github
        HostName github.com
        User git
        IdentityFile ${publicKeyFiles.diracGitHub}
        IdentitiesOnly yes
        IdentityAgent ${onePassPath}

    Host diraclocalserver
        HostName 192.168.1.244
        User diraclocalserver
        IdentityFile ${publicKeyFiles.diraclocalserver}
        IdentityAgent ${onePassPath}

    Host *
        IdentityAgent ${onePassPath}
  '';

  # You can test the result by running:
  #  SSH_AUTH_SOCK=~/.1password/agent.sock ssh-add -l
  xdg.configFile."1Password/ssh/agent.toml".source =
    let
      # full 1Password account IDs
      personalAccount = "L23KMYOBNVHLPGSIPDX7BAQ5LA";
      diracAccount = "PLU4HO2JCJF23NNQK2ERWIYIZI";
    in
    (pkgs.formats.toml { }).generate "1Password-ssh-agent.toml" {
      "ssh-keys" = [
        # dirac github
        {
          item = "drew-dirac SSH Key";
          vault = "Employee";
          account = diracAccount;
        }

        # rest of personal keys
        { account = personalAccount; }

        # diraclocalserver SSH Key
        {
          item = "diraclocalserver SSH Key";
          vault = "Engineering";
          account = diracAccount;
        }
      ];
    };

  # -------GIT CONFIGURATION-------
  programs = {
    git = {
      enable = true;
      lfs.enable = true;
      userEmail = "andrew.p.council@gmail.com";
      userName = "AndrewCouncil";
      delta = {
        enable = true;
        options = {
          side-by-side = false;
        };
      };
      extraConfig = {
        # preferences
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
        core.hooksPath = ".githooks";

        # 1password ssh commit signing
        user.signingkey = publicKeys.personalGitHub;
        gpg.format = "ssh";
        core.sshCommand = "ssh -i ${publicKeyFiles.personalGitHub}";
        # should be declared deterministically, but can't get same pkg as in nixos config
        "gpg \"ssh\"".program = "/run/current-system/sw/bin/op-ssh-sign";
        commit.gpgsign = true;
      };

      includes = [
        # dirac-specific git setup
        # need to `git init` in ~/dirac for this to work properly
        {
          condition = "gitdir:${vars.home}/dirac/";
          contentSuffix = ".dirac.gitconfig";
          contents = {
            user = {
              name = "drew-dirac";
              email = "drew@diracinc.com";
              signingkey = publicKeys.diracGitHub;
            };
            core.sshCommand = "ssh -i ${publicKeyFiles.diracGitHub}";
          };
        }
      ];
    };

    gh = {
      enable = true;
      extensions = with pkgs; [
        gh-s
        gh-i
        gh-f
        gh-copilot
        gh-markdown-preview
      ];
      settings = {
        git_protocol = "ssh";
        aliases = {
          cs = "copilot suggest";
          ce = "copilot explain";
        };
      };
    };

    gh-dash = {
      enable = true;
      settings = {
        pager.diff = "delta";
        repoPaths = {
          "diracq/*" = "~/dirac/*";
        };
        # keybindings.prs =
        #   let
        #     url = "https://github.com/{{.RepoName}}/pull/{{.PrNumber}}";
        #     command = "chromium-browser --ozone-platform-hint=auto --force-dark-mode --enable-features=WebUIDarkMode --app=${url} &> /dev/null &";
        #   in
        #   [
        #     {
        #       key = "o";
        #       inherit command;
        #     }
        #   ];
        prSections =
          let
            needReview = "is:open draft:false review:required";
          in
          [
            {
              title = "need my approval";
              filters = needReview + " -review:approved-by:@me -author:@me";
            }
            {
              title = "mine";
              filters = "is:open author:@me";
              layout.author.hidden = true;
            }
            {
              title = "review requested";
              filters = "is:open review-requested:@me";
            }
            {
              title = "all ready";
              filters = "is:open draft:false";
            }
            {
              title = "all";
              filters = "is:open";
            }
            {
              title = "need review";
              filters = needReview;
            }
          ];
      };
    };

    lazygit =
      let
        # https://github.com/jesseduffield/lazygit/blob/master/docs/Config.md#custom-command-for-copying-to-and-pasting-from-clipboard
        copyCmd = ''
          if [[ "$TERM" =~ ^(screen|tmux) ]]; then
            printf "\033Ptmux;\033\033]52;c;$(printf {{text}} | base64 -w 0)\a\033\\" > /dev/tty
          else
            printf "\033]52;c;$(printf {{text}} | base64 -w 0)\a" > /dev/tty
          fi
        '';
      in
      {
        enable = true;
        settings = {
          nerdFontsVersion = "3";
          showFileIcons = true;
          skipNoStagedFilesWarning = true;
          language = "en";
          update.method = "never";
          disableStartupPopups = true;
          notARepository = "quit";
          os = {
            copyToClipboardCmd = copyCmd;
            editPreset = "zed";
          };
          # skips drop to terminal from signing commit
          promptToReturnFromSubprocess = false;
          skipHookPrefix = "-";

          git = {
            paging = {
              colorArg = "always";
              pager = "delta --dark --paging=never";
            };
            # parseEmoji = true;
          };

          # customCommands = [
          #   {
          #     key = "C";
          #     context = "files";
          #     command = "git commit --no-verify";
          #     subprocess = true;
          #   }
          # ];
        };
      };

    gitui = {
      enable = true;
    };
  };
}
