{
  pkgs,
  lib,
  config,
  inputs,
  vars,
  ...
}:

{
  imports = [
    ./1password-gui.nix
    ./flatpak.nix
    ./fonts.nix
    ./kwallet.nix
    ./pwa.nix
  ];

  # Enable OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  environment.systemPackages =
    with pkgs;
    (
      [
        mesa-demos

        kdePackages.dolphin
        lxqt.pcmanfm-qt

        thunderbird
        libreoffice-qt6-fresh
        kdePackages.okular
        system-config-printer

        inputs.zen-browser.packages.${pkgs.system}.default
        # firefox in home manager

        qalculate-qt

        slack
        github-desktop
        postman
        # zoom-us

        pcloud
        localsend
        wireshark

        wayvnc
        libnotify
        gparted

        audacity
        gimp
        inkscape
        feh
        xournalpp
        kdePackages.kdenlive

        vlc
        mpv
        spotify
        calibre
        pdfarranger
        handbrake

        code-cursor
        zed-editor

        # failing to build, never use anyways
        # warp-terminal
        alacritty
        ghostty
        kitty

        kdePackages.qtwayland
        kdePackages.qtsvg
        kdePackages.qt6ct
        kdePackages.kio-fuse
        kdePackages.kio-extras
        kdePackages.plasma-workspace
        kdePackages.kconfig

        # codex
      ]
      ++ (
        if (vars.isPersonal config) then
          [
            qbittorrent

            # jellyfin-mpv-shim

            signal-desktop
            # element-desktop currently pulls in the insecure jitsi-meet-1.0.8792 package causing nix evaluation failures.
            # element-desktop

            apotris
            prismlauncher

            # emulation
            mame
            mame-tools
            dolphin-emu
            (retroarch.withCores (
              # specify retroarch cores to include
              cores: with cores; [
                # snes
                snes9x
                # gba
                mgba
                # nes
                mesen
                # psx
                beetle-psx-hw
              ]
            ))
          ]
        else
          [ ]
      )
    );

  # fix dolphin default programs
  # https://discourse.nixos.org/t/dolphin-does-not-have-mime-associations/48985/8
  environment.etc."/xdg/menus/applications.menu".text =
    builtins.readFile "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

  programs = {
    steam = lib.mkIf (vars.isPersonal config) {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    };

    virt-manager.enable = true;

    weylus = {
      enable = false;
      openFirewall = true;
      users = [ vars.user ];
    };
  };

  services = {
    mullvad-vpn = lib.mkIf (vars.isPersonal config) {
      enable = true;
      package = pkgs.mullvad-vpn;
    };

    # web ui for ollama and similar
    open-webui = {
      enable = false;
      port = 31743;
    };

    desktopManager.plasma6.enableQt5Integration = true;
  };

  # autostart steam in background
  systemd.user.services.steam = lib.mkIf (vars.isPersonal config) {
    enable = true;
    description = "Open Steam in the background at boot";
    serviceConfig = {
      ExecStart = "${lib.getExe pkgs.steam} -nochatui -nofriendsui -silent %U";
      wantedBy = [ "graphical-session.target" ];
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  # Set up virt manager
  users.groups.libvirtd.members = [ vars.user ];
  virtualisation = {
    libvirtd.enable = true;
    spiceUSBRedirection.enable = true;
  };

  # waydroid - android emulation
  virtualisation.waydroid = lib.mkIf (vars.isPersonal config) {
    enable = true;
  };

  catppuccin.enable = true;

  qt = {
    enable = true;
    platformTheme = "qt5ct";
    style = "kvantum";
  };
}
