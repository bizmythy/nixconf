{
  lib,
  vars,
  ...
}:
# configure neovim using nixvim
{
  programs.nixvim = {
    enable = true;
    plugins.lightline.enable = true;
  };
}
