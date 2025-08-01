{
  lib,
  pkgs,
  osConfig,
  vars,
  ...
}:

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
        igneous = {
          main = "desc:Microstep MSI MAG322UPF";
          top = "desc:ViewSonic Corporation VX2418-P FHD WFK231321682";
          tv = "desc:LG Electronics LG TV SSCR2 0x01010101";
        };
        drewdirac = {
          main = "desc:Samsung Electric Company U32J59x HCJXA01635";
          razer = "desc:Sharp Corporation LQ156T1JW03";
          right = "desc:LG Electronics LG SDQHD 409NTTQ8K433";
          top = "desc:Acer Technologies KA272 TJ0AA00785SJ";
        };
        theseus = {
          laptop = "desc:BOE 0x095F";
        };
        scaleHiDPI = "1.5";
        wsByHost = {
          drewdiracpc = [
            "1, monitor:${drewdirac.right}, default:true"
            "2, monitor:${drewdirac.main}, default:true"
            "8, monitor:${drewdirac.top}, default:true"
          ];
          igneous = [
            "1, monitor:${igneous.top}, default:true"
            "2, monitor:${igneous.main}, default:true"
            "10, monitor:${igneous.tv}, default:true"
          ];
        };

        launchWork = pkgs.writers.writeNu "laucnchwork" ''
          def launch [app: string, workspace: int] {
              hyprctl dispatch $"exec [workspace ($workspace) silent] ($app)"
          }

          launch "${vars.defaults.tty}" 1
          launch "slack" 8
          launch "${vars.defaults.editor} ~/dirac/buildos-web" 2
          launch "${vars.defaults.browser}" 3
        '';

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
          "hyprpaper"
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

        monitor = [
          " , preferred, auto, auto"

          "${igneous.main}, 3840x2160@160, 0x0, ${scaleHiDPI}"
          "${igneous.top}, 1920x1080@60, 575x-1080, 1.0"
          "${igneous.tv}, 3840x2160@120, auto-right, ${scaleHiDPI}"

          "${drewdirac.razer}, highres, auto, 1.333333"

          "${drewdirac.main}, 3840x2160, 0x0, ${scaleHiDPI}"
          "${drewdirac.right}, 2560x2880@60, auto-right, 1.333333"
          "${drewdirac.top}, 1920x1080@60, 575x-1080, 1.0"

          "${theseus.laptop}, preferred, auto, 1.566667"
        ];

        experimental.xx_color_management_v4 = (osConfig.networking.hostName == "igneous");

        workspace = wsByHost.${osConfig.networking.hostName} or [ ];

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

        gestures = {
          workspace_swipe = true;
          workspace_swipe_fingers = 3;
        };

        cursor = {
          no_hardware_cursors = true;
          inactive_timeout = 5;
        };

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
          "${modKey} SHIFT, D, exec, ${launchWork}"
          "${modKey}, N, exec, ${vars.defaults.editor} ${vars.home}/nixconf"

          "${modKey}, ${modKey}_L, exec, fuzzel"
          "${modKey}, V, exec, cliphist list | fuzzel --dmenu | cliphist decode | wl-copy"
          "${modKey}, SLASH, exec, bemoji -t"

          "${modKey}, COMMA, exec, playerctl previous"
          "${modKey}, PERIOD, exec, playerctl next"
          "${modKey}, SPACE, exec, playerctl play-pause"

          "${modKey}, W, killactive,"
          # "${modKey}, M, exit,"
          "${modKey}, F, togglefloating,"
          "${modKey}, M, fullscreen,"
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
          "${modKey}, PRINT, exec, hyprshot -z -m output"
          "${modKey} SHIFT, PRINT, exec, hyprshot -z -m window"
        ]);
        bindm = forAllModKeys (modKey: [
          # Move/resize windows with mainMod + LMB/RMB and dragging
          "${modKey}, mouse:272, movewindow"
          "${modKey}, mouse:273, resizewindow"
        ]);

        windowrulev2 =
          let
            floatingWindowRules = class: [
              "float, initialClass:${class}"
              "center, initialClass:${class}"
              "size 60% 60%, initialClass:${class}"
            ];
          in
          lib.lists.flatten [
            # (floatingWindowRules "1Password")
            (floatingWindowRules "io.github.Qalculate.qalculate-qt")
          ];

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

}
