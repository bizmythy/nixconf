{
  lib,
  vars,
  ...
}:
# configure neovim using nixvim
{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # set up color scheme
    colorschemes.catppuccin = {
      enable = true;
      # flavor = "mocha";
      # transparent_background = true;
    };

    opts = {
      number = true; # show line numbers
      relativenumber = true; # show relative line numbers

      shiftwidth = 2; # tab width 2

      clipboard = "unnamedplus"; # yank to and from system clipboard
    };

    globals.mapleader = " "; # Sets the leader key to space

    plugins = {
      lualine.enable = true;
    };
  };
}
