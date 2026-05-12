{
  config,
  inputs,
  lib,
  pkgs,
  osConfig,
  vars,
  ...
}:
let
  mkHyprlaunch = import ./hyprlaunch/mk-launcher.nix { inherit pkgs lib; };
  kittyHyprNav = import ./kitty-hypr-nav/package.nix { inherit pkgs lib; };
  switchaudio = import ./switchaudio/package.nix { inherit pkgs; };
  monitorConfig = import ./hyprland/monitor-config.nix;
  hostMonitorConfig = monitorConfig.hosts.${osConfig.networking.hostName} or { };
  profileLabels = [
    "default"
  ]
  ++ lib.sort lib.lessThan (lib.attrNames (hostMonitorConfig.profiles or { }));
  hyprlandPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  hyprlandPortalPackage =
    inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  toLua = lib.generators.toLua { };

  launchwork = mkHyprlaunch {
    name = "launchwork";
    directives = [
      {
        command = vars.defaults.tty;
        workspace = 1;
      }
      {
        command = "slack";
        workspace = 8;
      }
      {
        command = "${vars.defaults.editor} ${vars.home}/dirac/buildos-web";
        workspace = 2;
      }
      {
        command = vars.defaults.browser;
        workspace = 3;
      }
    ];
  };

  monitorProfileSelector = pkgs.writeShellApplication {
    name = "hypr-monitor-profile";
    text =
      let
        menuItems = lib.concatMapStringsSep " " lib.escapeShellArg profileLabels;
        fuzzel = lib.escapeShellArg (lib.getExe pkgs.fuzzel);
        hyprctl = lib.escapeShellArg (lib.getExe' hyprlandPackage "hyprctl");
        notifySend = lib.escapeShellArg (lib.getExe pkgs.libnotify);
        cases = lib.concatMapStringsSep "\n" (
          label:
          let
            lua = "require(\"nixconf.monitor_profiles\").apply_profile(${builtins.toJSON label})";
          in
          ''
            ${lib.escapeShellArg label})
              lua=${lib.escapeShellArg lua}
              ;;
          ''
        ) profileLabels;
      in
      ''
        choice="$(
          printf '%s\n' ${menuItems} \
            | ${fuzzel} --dmenu --prompt 'Monitors> '
        )" || exit 0

        [ -n "$choice" ] || exit 0

        case "$choice" in
        ${cases}
          *)
            ${notifySend} 'hyprmonitor' "unknown monitor profile: $choice"
            exit 1
            ;;
        esac

        output="$(${hyprctl} eval "$lua" 2>&1)" || {
          ${notifySend} 'hyprmonitor' "$output"
          exit 1
        }

        if [ "$output" != 'ok' ]; then
          ${notifySend} 'hyprmonitor' "$output"
        fi
      '';
  };

  generatedLua = {
    host = osConfig.networking.hostName;
    nvidia = osConfig.nvidiaEnable;
    defaults = {
      inherit (vars.defaults)
        browser
        calculator
        editor
        fileManager
        tty
        ;
      inherit (vars) home;
    };
    commands = {
      kwalletInit = "${pkgs.kdePackages.kwallet-pam}/libexec/pam_kwallet_init";
      launchwork = lib.getExe launchwork;
      kittyHyprNav = lib.getExe kittyHyprNav;
      monitorProfileSelector = lib.getExe monitorProfileSelector;
      switchaudio = lib.getExe switchaudio;
    };
    catppuccin = {
      mauve = "rgba(cba6f7ff)";
      pink = "rgba(f5c2e7ff)";
      accent = "mauve";
    };
    monitor = monitorConfig;
  };

in
{
  catppuccin.hyprland = {
    enable = false;
    accent = "mauve";
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.kdePackages.xdg-desktop-portal-kde
      pkgs.xdg-desktop-portal-gtk
    ];
  };

  # Write portal config file
  home.file.".config/xdg-desktop-portal/hyprland-portals.conf".text = ''
    [preferred]
    default = hyprland;gtk;kde
    org.freedesktop.impl.portal.FileChooser = kde
    org.freedesktop.impl.portal.Settings = gtk
    org.freedesktop.impl.portal.ScreenCast = hyprland
    org.freedesktop.impl.portal.Screenshot = hyprland
  '';

  wayland.windowManager.hyprland = {
    enable = true;
    package = hyprlandPackage;
    portalPackage = hyprlandPortalPackage;
    systemd.enable = false;
    xwayland = {
      enable = true;
    };
    settings = { };
  };

  xdg.configFile = {
    "hypr/hyprland.lua".text = ''
      local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
      package.path = config_home .. "/hypr/?.lua;" .. config_home .. "/hypr/?/init.lua;" .. package.path

      local modules = {
        "nixconf.generated",
        "nixconf.util",
        "nixconf.core",
        "nixconf.animations",
        "nixconf.autostart",
        "nixconf.monitor_profiles",
        "nixconf.binds",
      }

      for _, module in ipairs(modules) do
        package.loaded[module] = nil
      end

      require("nixconf.core")
      require("nixconf.animations")
      require("nixconf.autostart")
      require("nixconf.monitor_profiles")
      require("nixconf.binds")
    '';
    "hypr/nixconf/generated.lua".text = ''
      return ${toLua generatedLua}
    '';
    "hypr/nixconf/util.lua".source = ./hyprland/util.lua;
    "hypr/nixconf/core.lua".source = ./hyprland/core.lua;
    "hypr/nixconf/animations.lua".source = ./hyprland/animations.lua;
    "hypr/nixconf/autostart.lua".source = ./hyprland/autostart.lua;
    "hypr/nixconf/binds.lua".source = ./hyprland/binds.lua;
    "hypr/nixconf/monitor_profiles.lua".source = ./hyprland/monitor_profiles.lua;
  };

  systemd.user.targets.hyprland-session = {
    Unit = {
      Description = "Hyprland compositor session";
      Documentation = [ "man:systemd.special(7)" ];
      BindsTo = [ "graphical-session.target" ];
      Wants = [ "graphical-session-pre.target" ];
      After = [ "graphical-session-pre.target" ];
    };
  };

  home.packages = [
    launchwork
    monitorProfileSelector
  ];
}
