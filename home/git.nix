{
  pkgs,
  ...
}:
let
  personalGithubID = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOjbUnES0AUVvsqNzMdCix3Qp+XRpKiS7tm6PR6u7WTY";
  diracGithubID = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIrRXpZt/U8OkMsWoft9+2JiITBsUyGVxuhZJhl+Xpm";

  sshCommand =
    filename: id:
    let
      pubKeyFile = pkgs.writeTextFile {
        name = filename;
        text = id;
      };
    in
    "ssh -i ${pubKeyFile}";
in
{
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

        # configure multiple git accounts
        core.sshCommand = sshCommand "personal_id.pub" personalGithubID;

        # 1password ssh commit signing
        user.signingkey = personalGithubID;
        gpg.format = "ssh";
        # should be declared deterministically, but can't get same pkg as in nixos config
        "gpg \"ssh\"".program = "/run/current-system/sw/bin/op-ssh-sign";
        commit.gpgsign = true;
      };

      includes = [
        # dirac-specific git setup
        # need to `git init` in ~/dirac for this to work properly
        {
          condition = "gitdir:/home/drew/dirac/";
          contentSuffix = ".dirac.gitconfig";
          contents = {
            user = {
              name = "drew-dirac";
              email = "drew@diracinc.com";
              signingkey = diracGithubID;
            };
            core.sshCommand = sshCommand "dirac_id.pub" diracGithubID;
          };
        }
      ];
    };

    gh = {
      enable = true;
      settings = {
        git_protocol = "ssh";
        # aliases = {};
      };
    };

    gh-dash = {
      enable = true;
      settings = {
        pager.diff = "delta";
        repoPaths = {
          "diracq/*" = "~/dirac/*";
        };
        prSections = [
          {
            title = "need review";
            filters = "is:open draft:false review:required -review:approved-by:@me";
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
  };
}
