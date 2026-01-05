{
  lib,
  pkgs,
  vars,
  osConfig,
  ...
}:

{
  imports = [
    # keep-sorted start
    ./bat.nix
    ./btop.nix
    ./chromium.nix
    ./feh.nix
    ./firefox.nix
    ./gh.nix
    ./helix.nix
    ./lazydocker.nix
    ./lazygit.nix
    ./nvim.nix
    ./op.nix
    ./scripts
    ./shell.nix
    ./spotify-player.nix
    ./ssh-git.nix
    ./theme.nix
    ./tty/tty.nix
    ./vesktop.nix
    ./wm
    ./xdg-mime.nix
    # keep-sorted end
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = vars.user;
  home.homeDirectory = vars.home;

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "24.11"; # Please read the comment before changing.

  # home.packages = with pkgs; [
  # ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # text expander
  # services.espanso = {
  #   enable = true;
  # };
}
