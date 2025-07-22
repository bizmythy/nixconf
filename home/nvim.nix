{
  lib,
  vars,
  ...
}:
# configure neovim using nixvim
{
  programs.nixvim = {
    enable = true;
    colorschemes.catppuccin = {
      enable = true;
      flavor = "mocha";
    };
    # plugins.lightline.enable = true;
  };
}
