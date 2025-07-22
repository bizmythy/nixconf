{
  pkgs,
  ...
}:
let
  # plugin that toggles between relative and absolute line number based on mode
  numbertoggle = pkgs.vimUtils.buildVimPlugin {
    name = "nvim-numbertoggle";
    src = pkgs.fetchFromGitHub {
      owner = "sitiom";
      repo = "nvim-numbertoggle";
      rev = "4b898b84d6f31f76bd563330d76177d5eb299efa";
      hash = "sha256-NTcbTBzK9otf73dutdWpYwyphXhKVoa6sr5vTg56tLk=";
    };
  };
in
{
  # configure neovim using nixvim
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # set up color scheme
    colorschemes.catppuccin = {
      enable = true;
      settings = {
        flavor = "mocha";
        transparent_background = true;
      };
    };

    opts = {
      number = true; # show line numbers
      relativenumber = true; # show relative line numbers
      wrap = false; # do not wrap lines
      sidescroll = 1; # allow horizontal scrolling

      shiftwidth = 2; # tab width 2
      expandtab = true; # use spaces instead of tabs
      fileformat = "unix"; # set file format to unix

      exrc = true; # allow use of a local .nvimrc file

      clipboard = "unnamed"; # yank to and from system clipboard

      colorcolumn = "80"; # show color column at 80 characters

      # show special characters
      list = true;
      listchars = "tab:▸▸,trail:·"; # show tabs and trailing whitespace

      mouse = "a"; # enable mouse mode
    };

    globals.mapleader = " "; # sets the leader key to space

    keymaps = [
      # use double leader to switch between buffers
      {
        mode = "n";
        key = "<leader><leader>";
        action = ":b#<CR>";
        options = {
          desc = "Switch to previous buffer";
        };
      }
    ];

    plugins = {
      # keep-sorted start
      lualine.enable = true;
      scrollview.enable = true;
      direnv.enable = true;
      oil.enable = true;
      telescope.enable = true;
      web-devicons.enable = true;
      # keep-sorted end

      # treesitter configuration
      treesitter = {
        enable = true;
        settings = {
          highlight = {
            enable = true;
            additional_vim_regex_highlighting = true;
          };
          indent.enable = true;
          incremental_selection.enable = true;
        };
      };
    };

    extraPlugins = [ numbertoggle ];
  };
}
