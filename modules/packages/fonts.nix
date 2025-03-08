{
  pkgs,
  ...
}:

{
  # configure fonts
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.hack
      nerd-fonts.fira-code
      nerd-fonts.ubuntu-mono

      noto-fonts
      noto-fonts-color-emoji
      ibm-plex
    ];

    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ "JetBrainsMono Nerd Font" ];
        sansSerif = [ "Noto Sans" ];
        serif = [ "Noto Serif" ];
      };
    };
  };
}
