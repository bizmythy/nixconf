{
  config,
  lib,
  pkgs,
  osConfig,
  vars,
  ...
}:
let
  hyprmonitor = config.wm.hyprmonitor;
  mkHyprlaunch = import ./hyprlaunch/mk-launcher.nix { inherit pkgs lib; };

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

in
{
  catppuccin.hyprland = {
    enable = true;
    accent = "mauve";
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Write portal config file
  home.file.".config/xdg-desktop-portal/hyprland-portals.conf".text = ''
    [preferred]
    default = hyprland;gtk
    org.freedesktop.impl.portal.FileChooser = gtk
  '';

  wayland.windowManager.hyprland = {
    enable = true;
    xwayland = {
      enable = true;
    };
    settings =
      let
        # for each mod key, call the function. take the lists of binds,
        # flatten them, and ensure they are unique.
        forAllModKeys =
          let
            modKeys =
              # if osConfig.networking.hostName == "theseus" then
              #   [
              #     "SUPER"
              #     "ALT_R"
              #   ]
              # else
              [
                "SUPER"
              ];
          in
          bindFunc: lib.lists.unique (lib.lists.flatten (map bindFunc modKeys));
      in
      {
        xwayland.force_zero_scaling = true;
        exec-once = [
          "${pkgs.kdePackages.kwallet-pam}/libexec/pam_kwallet_init"
          "${lib.getExe hyprmonitor.package} --apply-default" # apply default monitor config
          "waybar"
          "systemctl --user start hyprpolkitagent"
          "swaync"
          "wl-paste --type text --watch cliphist store"
          "wl-paste --type image --watch cliphist store"
          "udiskie"
          "nm-applet"
          "blueman-applet"
          "1password --silent"
          "pcloud"
          # "[workspace special:magic silent] '${vars.defaults.tty} -e btop'"
        ];

        env =
          [ ]
          ++ (
            if osConfig.nvidiaEnable then
              [
                "LIBVA_DRIVER_NAME,nvidia"
                "__GLX_VENDOR_LIBRARY_NAME,nvidia"
                "WLR_NO_HARDWARE_CURSORS,1"
                "OGL_DEDICATED_HW_STATE_PER_CONTEXT,ENABLE_ROBUST"
              ]
            else
              [ ]
          );

        general = {
          "col.active_border" = "$mauve $pink 90deg";
          gaps_in = 5;
          gaps_out = 10;
        };

        decoration = {
          rounding = 14;
        };

        source = lib.mkAfter [
          hyprmonitor.configPath # managed by `hyprmonitor` script
        ];

        input = {
          kb_layout = "us";
          follow_mouse = 1;
          mouse_refocus = false;
          touchpad = {
            natural_scroll = true;
          };
          sensitivity = -0.2;
          accel_profile = "flat";
          numlock_by_default = true;
          kb_options = "caps:escape";
        };

        cursor = {
          no_hardware_cursors = true;
          inactive_timeout = 5;
        };

        # trackpad gestures
        gesture = [
          "3, horizontal, workspace"
        ];

        # keybinds
        bind = forAllModKeys (modKey: [
          "${modKey}, RETURN, exec, ${vars.defaults.tty}"
          # "${modKey} SHIFT, RETURN, exec, ${vars.defaults.tty}"
          "${modKey}, E, exec, ${vars.defaults.fileManager}"
          "${modKey}, B, exec, ${vars.defaults.browser}"
          "${modKey} SHIFT, B, exec, ${vars.defaults.browser} --private-window duckduckgo.com"
          "${modKey}, P, exec, hyprpicker -a"
          "${modKey}, EQUAL, exec, ${vars.defaults.calculator}"

          "${modKey}, Z, exec, ${vars.defaults.editor}"
          "${modKey}, D, exec, ${vars.defaults.editor} ${vars.home}/dirac/buildos-web"
          "${modKey} SHIFT, D, exec, ${lib.getExe launchwork}"
          "${modKey}, N, exec, ${vars.defaults.editor} ${vars.home}/nixconf"

          "${modKey}, ${modKey}_L, exec, fuzzel"
          "${modKey}, V, exec, cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"
          "${modKey}, SLASH, exec, bemoji -t"

          "${modKey}, COMMA, exec, playerctl previous"
          "${modKey}, PERIOD, exec, playerctl next"
          "${modKey}, SPACE, exec, playerctl play-pause"

          "${modKey}, W, killactive,"
          "${modKey}, F, togglefloating,"
          "${modKey} SHIFT, M, fullscreen,"
          "${modKey}, M, exec, ${lib.getExe hyprmonitor.package}"
          # "${modKey}, P, pseudo," # dwindle
          # "${modKey}, J, togglesplit," # dwindle

          # Move focus with mainMod + arrow keys or VIM keys
          "${modKey}, left, movefocus, l"
          "${modKey}, H, movefocus, l"
          "${modKey}, right, movefocus, r"
          "${modKey}, L, movefocus, r"
          "${modKey}, up, movefocus, u"
          "${modKey}, K, movefocus, u"
          "${modKey}, down, movefocus, d"
          "${modKey}, J, movefocus, d"

          # Resize active window with mainMod + ALT + arrow keys or VIM keys
          "${modKey} ALT, left, resizeactive, -5% 0"
          "${modKey} ALT, H, resizeactive, -5% 0"
          "${modKey} ALT, right, resizeactive, 5% 0"
          "${modKey} ALT, L, resizeactive, 5% 0"
          "${modKey} ALT, up, resizeactive, 0 -5%"
          "${modKey} ALT, K, resizeactive, 0 -5%"
          "${modKey} ALT, down, resizeactive, 0 5%"
          "${modKey} ALT, J, resizeactive, 0 5%"

          "${modKey}, Tab, cyclenext" # change focus to another window
          "${modKey}, Tab, bringactivetotop" # bring it to the top

          # Switch workspaces with mainMod + [0-9]
          "${modKey}, 1, focusworkspaceoncurrentmonitor, 1"
          "${modKey}, 2, focusworkspaceoncurrentmonitor, 2"
          "${modKey}, 3, focusworkspaceoncurrentmonitor, 3"
          "${modKey}, 4, focusworkspaceoncurrentmonitor, 4"
          "${modKey}, 5, focusworkspaceoncurrentmonitor, 5"
          "${modKey}, 6, focusworkspaceoncurrentmonitor, 6"
          "${modKey}, 7, focusworkspaceoncurrentmonitor, 7"
          "${modKey}, 8, focusworkspaceoncurrentmonitor, 8"
          "${modKey}, 9, focusworkspaceoncurrentmonitor, 9"
          "${modKey}, 0, focusworkspaceoncurrentmonitor, 10"

          "${modKey} CONTROL, H, workspace, e-1"
          "${modKey} CONTROL, L, workspace, e+1"
          "${modKey} CONTROL, left, workspace, e-1"
          "${modKey} CONTROL, right, workspace, e+1"

          # Move active window to a workspace with mainMod + SHIFT + [0-9]
          "${modKey} SHIFT, 1, movetoworkspace, 1"
          "${modKey} SHIFT, 2, movetoworkspace, 2"
          "${modKey} SHIFT, 3, movetoworkspace, 3"
          "${modKey} SHIFT, 4, movetoworkspace, 4"
          "${modKey} SHIFT, 5, movetoworkspace, 5"
          "${modKey} SHIFT, 6, movetoworkspace, 6"
          "${modKey} SHIFT, 7, movetoworkspace, 7"
          "${modKey} SHIFT, 8, movetoworkspace, 8"
          "${modKey} SHIFT, 9, movetoworkspace, 9"
          "${modKey} SHIFT, 0, movetoworkspace, 10"

          "${modKey} SHIFT, H, movetoworkspace, e-1"
          "${modKey} SHIFT, L, movetoworkspace, e+1"
          "${modKey} SHIFT, left, movetoworkspace, e-1"
          "${modKey} SHIFT, right, movetoworkspace, e+1"

          # Example special workspace (scratchpad)
          # "${modKey}, S, togglespecialworkspace, magic"
          # "${modKey} CTRL, S, movetoworkspace, special:magic"

          # Scroll through existing workspaces with mainMod + scroll
          "${modKey}, mouse_down, workspace, e+1"
          "${modKey}, mouse_up, workspace, e-1"
          ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%+"
          ", XF86AudioLowerVolume, exec, wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%-"
          ", XF86MonBrightnessUp, exec, brightnessctl s +5%"
          ", XF86MonBrightnessDown, exec, brightnessctl s 5%-"
          ", XF86AudioPlay, exec, playerctl play-pause"
          ", XF86AudioPause, exec, playerctl play-pause"
          ", XF86AudioNext, exec, playerctl next"
          ", XF86AudioPrev, exec, playerctl previous"

          # Screenshots
          ", PRINT, exec, hyprshot -z -m region"
          "${modKey} SHIFT, S, exec, hyprshot -z -m region"
          "${modKey} CTRL, S, exec, hyprshot -z -m output"
          "${modKey}, PRINT, exec, hyprshot -z -m output"
          "${modKey} SHIFT, PRINT, exec, hyprshot -z -m window"
        ]);
        bindm = forAllModKeys (modKey: [
          # Move/resize windows with mainMod + LMB/RMB and dragging
          "${modKey}, mouse:272, movewindow"
          "${modKey}, mouse:273, resizewindow"
        ]);

        # not working, should figure out
        # windowrulev2 =
        #   let
        #     floatingWindowRules = class: {
        #       name = "float-${class}";
        #       "match:initial_class" = class;
        #       float = true;
        #       center = true;
        #       size = "60% 60%";
        #     };
        #   in
        #   lib.lists.flatten [
        #     # (floatingWindowRules "1Password")
        #     (floatingWindowRules "io.github.Qalculate.qalculate-qt")
        #   ];

        animations = {
          enabled = true;

          bezier = [
            "easeOutQuint,0.23,1,0.32,1"
            "easeInOutCubic,0.65,0.05,0.36,1"
            "linear,0,0,1,1"
            "almostLinear,0.5,0.5,0.75,1.0"
            "quick,0.15,0,0.1,1"
          ];

          animation =
            let
              winMoveSpeed = "1.5";
            in
            [
              "global, 1, 10, default"
              "border, 1, 5.39, easeOutQuint"
              "windows, 1, 4.79, easeOutQuint"
              "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
              "windowsOut, 1, 1.49, linear, popin 87%"
              "windowsMove, 1, ${winMoveSpeed}, easeOutQuint, slide"
              "fadeIn, 1, 1.73, almostLinear"
              "fadeOut, 1, 1.46, almostLinear"
              "fade, 1, 3.03, quick"
              "layers, 1, 3.81, easeOutQuint"
              "layersIn, 1, 4, easeOutQuint, fade"
              "layersOut, 1, 1.5, linear, fade"
              "fadeLayersIn, 1, 1.79, almostLinear"
              "fadeLayersOut, 1, 1.39, almostLinear"
              "workspaces, 0, 1.94, almostLinear, fade"
            ];
        };

        ecosystem = {
          no_update_news = true;
          no_donation_nag = true;
        };
        misc = {
          disable_hyprland_logo = true;
          middle_click_paste = false;
        };
      };
  };
  home.packages = [ launchwork ];
}
