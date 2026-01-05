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
    ./programs
    ./scripts
    ./shell.nix
    ./ssh-git.nix
    ./theme.nix
    ./tty/tty.nix
    ./wm
    ./xdg-mime.nix
    # keep-sorted end
  ];

  home =
    let
      homeDirectory = vars.home;
    in
    {
      # Home Manager needs a bit of information about you and the paths it should
      # manage.
      username = vars.user;
      inherit homeDirectory;

      # This value determines the Home Manager release that your configuration is
      # compatible with. This helps avoid breakage when a new Home Manager release
      # introduces backwards incompatible changes.
      #
      # You should not change this value, even if you update Home Manager. If you do
      # want to update the value, then make sure to first check the Home Manager
      # release notes.
      stateVersion = "24.11"; # Please read the comment before changing.

      sessionPath = [
        "${homeDirectory}/.cargo/bin" # programs from `cargo install`
      ];
    };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # text expander
  # services.espanso = {
  #   enable = true;
  # };
}
