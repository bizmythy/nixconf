{
  config,
  pkgs,
  inputs,
  vars,
  lib,
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
          side-by-side = true;
        };
      };
      extraConfig = {
        push = {
          autoSetupRemote = true;
        };
        "includeIf \"gitdir:${diracPath}\"" = {
          path = "${diracGitConf}";
        };
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
        repoPaths = {
          "diracq/*" = "~/dirac/*";
        };
      };
    };

    lazygit = {
      enable = true;
      settings = {
        nerdFontsVersion = "3";
        showFileIcons = true;
        # TODO: this is not working...
        git = {
          paging = {
            colorArg = "always";
            pager = "delta --dark --paging=never";
          };
        };
      };
    };
  };
}
