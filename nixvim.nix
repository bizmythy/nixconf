{
  pkgs,
  ...
}:

# configure neovim using nixvim
{
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
    wrap = true; # wrap lines
    sidescroll = 1; # allow horizontal scrolling

    shiftwidth = 2; # tab width 2
    expandtab = true; # use spaces instead of tabs
    fileformat = "unix"; # set file format to unix

    exrc = true; # allow use of a local .nvimrc file

    clipboard = "unnamedplus"; # yank to and from system clipboard

    colorcolumn = "80"; # show color column at 80 characters

    # show special characters
    list = true;
    listchars = "tab:▸▸,trail:·"; # show tabs and trailing whitespace

    mouse = "a"; # enable mouse mode
  };

  globals.mapleader = " "; # sets the leader key to space
  globals.maplocalleader = "\\"; # sets the local leader key to \

  keymaps = [
    # use double leader to switch between buffers
    {
      mode = "n";
      key = "<leader><leader>";
      action = ":b#<CR>";
      options.desc = "Switch to previous buffer";
    }

    {
      mode = "n";
      key = "<leader>q";
      action = ":wq<CR>";
      options.desc = "Write file and quit";
    }

    {
      mode = "n";
      key = "<localleader>n";
      action = "<cmd>normal <localleader><Space>]u<CR>";
    }
  ];

  plugins = {
    # keep-sorted start
    direnv.enable = true;
    lualine.enable = true;
    octo.enable = true;
    oil.enable = true;
    scrollview.enable = true;
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

  extraPlugins = [
    # plugin that toggles between relative and absolute line number based on mode
    (pkgs.vimUtils.buildVimPlugin {
      name = "nvim-numbertoggle";
      src = pkgs.fetchFromGitHub {
        owner = "sitiom";
        repo = "nvim-numbertoggle";
        rev = "4b898b84d6f31f76bd563330d76177d5eb299efa";
        hash = "sha256-NTcbTBzK9otf73dutdWpYwyphXhKVoa6sr5vTg56tLk=";
      };
    })

    # plugin that colorizes ANSI escape sequences
    (pkgs.vimUtils.buildVimPlugin {
      name = "baleia";
      src = pkgs.fetchFromGitHub {
        owner = "m00qek";
        repo = "baleia.nvim";
        rev = "1b25eac3ac03659c3d3af75c7455e179e5f197f7";
        hash = "sha256-qA1x5kplP2I8bURO0I4R0gt/zeznu9hQQ+XHptLGuwc=";
      };
    })
  ];

  extraConfigLua = ''
    -- Baleia Setup
    vim.g.baleia = require("baleia").setup({ })

    -- Command to colorize the current buffer
    vim.api.nvim_create_user_command("BaleiaColorize", function()
      vim.g.baleia.once(vim.api.nvim_get_current_buf())
    end, { bang = true })

    -- Command to show logs 
    vim.api.nvim_create_user_command("BaleiaLogs", vim.g.baleia.logger.show, { bang = true })
  '';
}
