{
  pkgs,
  ...
}:
let
  diracPath = "/home/drew/dirac";
  diracGitConf = (pkgs.formats.ini { }).generate ".gitconfig-dirac" {
    user = {
      name = "drew-dirac";
      email = "drew@diracinc.com";
    };
  };
in
{
  programs = {
    git = {
      enable = true;
      userEmail = "andrew.p.council@gmail.com";
      userName = "AndrewCouncil";
      delta = {
        enable = true;
        options = {
          side-by-side = false;
        };
      };
      extraConfig = {
        push = {
          autoSetupRemote = true;
        };
        core.hooksPath = ".githooks";
        "includeIf \"gitdir:${diracPath}\"" = {
          path = "${diracGitConf}";
        };
        init.defaultBranch = "main";
      };
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

          git = {
            paging = {
              colorArg = "always";
              pager = "delta --dark --paging=never";
            };
            # parseEmoji = true;
          };
        };
      };
  };
}
