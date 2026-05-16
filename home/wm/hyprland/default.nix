{
  lib,
  pkgs,
  osConfig,
  vars,
  ...
}:
let
  kittyHyprNav = import ../kitty-hypr-nav/package.nix { inherit pkgs lib; };
  switchaudio = import ../switchaudio/package.nix { inherit pkgs; };
  monitorConfig = import ./monitor-config.nix;
  hostMonitorConfig = monitorConfig.hosts.${osConfig.networking.hostName} or { };
  profileLabels = [
    "default"
  ]
  ++ lib.sort lib.lessThan (lib.attrNames (hostMonitorConfig.profiles or { }));
  hyprlandPackage = pkgs.hyprland;
  hyprlandPortalPackage = pkgs.xdg-desktop-portal-hyprland;
  toLua = lib.generators.toLua { };

  launchworkDirectives = [
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
            profile = (hostMonitorConfig.profiles or { }).${label} or { };
          in
          # bash
          ''
            ${lib.escapeShellArg label})
              use_tablet=${if profile.useTablet or false then "1" else "0"}
              ;;
          ''
        ) profileLabels;
      in
      # bash
      ''
        log="''${XDG_RUNTIME_DIR:-/tmp}/hypr-monitor-profile.log"
        {
          printf '[%s] launch WAYLAND_DISPLAY=%s DISPLAY=%s XDG_RUNTIME_DIR=%s\n' \
            "$(date --iso-8601=seconds)" \
            "''${WAYLAND_DISPLAY:-}" \
            "''${DISPLAY:-}" \
            "''${XDG_RUNTIME_DIR:-}"
        } >>"$log"

        choice="$(
          printf '%s\n' ${menuItems} \
            | ${fuzzel} --dmenu --prompt 'Monitors> '
        )" || {
          status=$?
          printf '[%s] fuzzel exited with %s\n' "$(date --iso-8601=seconds)" "$status" >>"$log"
          exit 0
        }

        [ -n "$choice" ] || {
          printf '[%s] no profile selected\n' "$(date --iso-8601=seconds)" >>"$log"
          exit 0
        }

        case "$choice" in
        ${cases}
          *)
            ${notifySend} 'hyprmonitor' "unknown monitor profile: $choice"
            exit 1
            ;;
        esac

        printf '[%s] selected %s\n' "$(date --iso-8601=seconds)" "$choice" >>"$log"

        if [ "$use_tablet" = '1' ]; then
          ${hyprctl} output create headless ${lib.escapeShellArg monitorConfig.tabletHeadless.name} >>"$log" 2>&1 || true
        else
          ${hyprctl} output remove ${lib.escapeShellArg monitorConfig.tabletHeadless.name} >>"$log" 2>&1 || true
        fi

        request_id="$(date +%s%N)"
        printf '%s\n%s\n' "$request_id" "$choice" >"''${XDG_RUNTIME_DIR:-/tmp}/hyprmonitor-profile-request"
        printf '[%s] queued request %s for %s\n' "$(date --iso-8601=seconds)" "$request_id" "$choice" >>"$log"
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
      kittyHyprNav = lib.getExe kittyHyprNav;
      monitorProfileSelector = lib.getExe monitorProfileSelector;
      switchaudio = lib.getExe switchaudio;
    };
    catppuccin = {
      mauve = "rgba(cba6f7ff)";
      pink = "rgba(f5c2e7ff)";
      accent = "mauve";
    };
    launchers = {
      launchwork = launchworkDirectives;
    };
    monitor = monitorConfig;
  };

  # lua module files in require order
  luaModules = [
    "core"
    "util"
    "animations"
    "autostart"
    "monitor_profiles"
    "binds"
  ];

  luaModuleRequires = map (module: "nixconf.${module}") luaModules;

  luaModuleConfigFiles = lib.listToAttrs (
    map (module: {
      name = "hypr/nixconf/${module}.lua";
      value.source = ./src + "/${module}.lua";
    }) luaModules
  );

  luaModuleClearLines = lib.concatMapStringsSep "\n" (module: ''package.loaded["${module}"] = nil'') (
    [ "nixconf.generated" ] ++ luaModuleRequires
  );
  luaModuleRequireLines = lib.concatMapStringsSep "\n" (
    module: ''require("${module}")''
  ) luaModuleRequires;

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
    "hypr/hyprland.lua".text = # lua
      ''
        local config_home = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
        package.path = config_home .. "/hypr/?.lua;" .. config_home .. "/hypr/?/init.lua;" .. package.path

        ${luaModuleClearLines}

        ${luaModuleRequireLines}
      '';
    "hypr/nixconf/generated.lua".text = # lua
      ''
        return ${toLua generatedLua}
      '';
  }
  // luaModuleConfigFiles;

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
    monitorProfileSelector
  ];
}
