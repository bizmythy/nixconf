{
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ../kwallet.nix
  ];

  environment.systemPackages = with pkgs; [
    kdePackages.dolphin
    lxqt.pcmanfm-qt

    thunderbird
    kdePackages.okular

    google-chrome
    inputs.zen-browser.packages.${pkgs.system}.default
    # firefox in home manager

    qalculate-qt
    logseq

    slack
    github-desktop
    postman

    pcloud
    localsend
    wireshark

    ventoy
    gparted

    gimp
    kdePackages.kdenlive

    vlc
    mpv
    spotify

    code-cursor
    zed-editor

    warp-terminal
    alacritty
    ghostty

    kdePackages.qtwayland
    kdePackages.qtsvg
    kdePackages.qt6ct
    kdePackages.kio-fuse
    kdePackages.kio-extras
    kdePackages.plasma-workspace
    kdePackages.kconfig
  ];

  services.flatpak = {
    enable = true;
    update.auto = {
      enable = true;
      onCalendar = "weekly";
    };

    # flatpak packages
    packages = [
      "com.obsproject.Studio"
      "org.signal.Signal"
      "com.discordapp.Discord"
      "com.github.tchx84.Flatseal"
      "us.zoom.Zoom"
    ];
  };

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

  programs = {
    _1password-gui = {
      enable = true;
      # Certain features, including CLI integration and system authentication support,
      # require enabling PolKit integration on some desktop environments (e.g. Plasma).
      polkitPolicyOwners = [ "drew" ];
    };

    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };

    virt-manager.enable = true;
  };

  # Set up virt manager
  users.groups.libvirtd.members = [ "drew" ];
  virtualisation = {
    libvirtd.enable = true;
    spiceUSBRedirection.enable = true;
  };

  environment.etc = {
    "1password/custom_allowed_browsers" = {
      text = ''
        .zen-wrapped
      '';
      mode = "0755";
    };
  };

  catppuccin.enable = true;

  services.desktopManager.plasma6.enableQt5Integration = true;
  qt = {
    enable = true;
    platformTheme = "qt5ct";
    style = "kvantum";
  };
}
