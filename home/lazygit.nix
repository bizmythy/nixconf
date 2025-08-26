{ ... }:
{
  programs.lazygit = {
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
        editPreset = "zed";

        # https://github.com/jesseduffield/lazygit/blob/master/docs/Config.md#custom-command-for-copying-to-and-pasting-from-clipboard
        copyToClipboardCmd = ''
          if [[ "$TERM" =~ ^(screen|tmux) ]]; then
            printf "\033Ptmux;\033\033]52;c;$(printf {{text}} | base64 -w 0)\a\033\\" > /dev/tty
          else
            printf "\033]52;c;$(printf {{text}} | base64 -w 0)\a" > /dev/tty
          fi
        '';
      };

      # skips drop to terminal from signing commit
      promptToReturnFromSubprocess = false;
      skipHookPrefix = "-";

      git = {
        # allow rewording of signed commits, I use op as ssh signing agent
        overrideGpg = true;
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

  catppuccin.lazygit.enable = true;

  programs.gitui.enable = false;
}
