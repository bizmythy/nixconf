{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./waybar/waybar.nix
  ];

  dconf = {
    enable = true;
    settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
  };

  catppuccin.hyprland = {
    enable = true;
    accent = "mauve";
  };

  home.pointerCursor = {
    name = "phinger-cursors-dark";
    package = pkgs.phinger-cursors;
    size = 32;
  };

  services.hyprpaper =
    let
      wallpaper = pkgs.fetchurl {
        url = "https://filedn.com/l0xkAHTdfcEJNc2OW7dfBny/purple_crystals.jpg";
        sha256 = "0fyrzlbx6ii9nzpn2vpl45vdq9hh87af18d3sjpvv66cbsc9vwga";
      };
    in
    {
      enable = true;
      settings = {
        preload = wallpaper.outPath;
        wallpaper = " , ${wallpaper.outPath}";
      };
    };

  home.sessionVariables = {
    HYPRSHOT_DIR = "/home/drew/Pictures/screenshots";
  };

  # Write portal config file
  home.file.".config/xdg-desktop-portal/hyprland-portals.conf".text = ''
    [preferred]
    default = hyprland;gtk
    org.freedesktop.impl.portal.FileChooser = kde
  '';

  wayland.windowManager.hyprland = {
    enable = true;
    xwayland.enable = true;

    settings = {
      exec-once = [
        "hyprpaper"
        "waybar"
        "systemctl --user start hyprpolkitagent"
        "swaync"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        "udiskie"
        "nm-applet"
        "blueman-applet"
      ];

      general = {
        "col.active_border" = "$mauve $pink 90deg";
        "gaps_in" = 5;
        "gaps_out" = 10;
      };

      decoration = {
        "rounding" = 14;
      };

      monitor = [
        " , preferred, auto, auto"
        "desc:Microstep MSI MAG322UPF, highres, auto-up, 1.25"
	"desc:LG Electronics LG SDQHD 409NTTQ8K433, highres, auto-up, 1.25, transform, 3"
        "desc:Sharp Corporation LQ156T1JW03, highres, auto, 1.333333"
      ];

      input = {
        "kb_layout" = "us";
        "follow_mouse" = 1;
        "touchpad" = {
          "natural_scroll" = false;
        };
        "sensitivity" = -0.2;
        "accel_profile" = "flat";
        "numlock_by_default" = true;

        "kb_options" = "caps:escape";
      };

      gestures = {
        workspace_swipe = true;
        workspace_swipe_fingers = 3;
      };

      "$mainMod" = "SUPER";

      "$terminal" = "alacritty";
      "$fileManager" = "pcmanfm-qt";
      "$menu" = "fuzzel";
      "$browser" = "zen";
      "$calculator" = "qalculate-qt";

      bind = [
        # Example binds, see https://wiki.hyprland.org/Configuring/Binds/ for more
        "$mainMod, RETURN, exec, $terminal"
        "$mainMod, E, exec, $fileManager"
        "$mainMod, B, exec, $browser"
        "$mainMod, P, exec, hyprpicker"
        "$mainMod, EQUAL, exec, $calculator"

        "SUPER, SUPER_L, exec, fuzzel"
        "$mainMod, V, exec, cliphist list | $menu --dmenu | cliphist decode | wl-copy"
        "$mainMod, PERIOD, exec, bemoji -t"

        "$mainMod, W, killactive,"
        "$mainMod, M, exit,"
        "$mainMod, F, togglefloating,"
        "$mainMod, P, pseudo," # dwindle
        "$mainMod, J, togglesplit," # dwindle

        # Move focus with mainMod + arrow keys or VIM keys
        "$mainMod, left, movefocus, l"
        "$mainMod, H, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, L, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, K, movefocus, u"
        "$mainMod, down, movefocus, d"
        "$mainMod, J, movefocus, d"

        "$mainMod, Tab, cyclenext" # change focus to another window
        "$mainMod, Tab, bringactivetotop" # bring it to the top

        # Switch workspaces with mainMod + [0-9]
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"

        "$mainMod CONTROL, H, workspace, e-1"
        "$mainMod CONTROL, L, workspace, e+1"
        "$mainMod CONTROL, left, workspace, e-1"
        "$mainMod CONTROL, right, workspace, e+1"

        # Move active window to a workspace with mainMod + SHIFT + [0-9]
        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
        "$mainMod SHIFT, 6, movetoworkspace, 6"
        "$mainMod SHIFT, 7, movetoworkspace, 7"
        "$mainMod SHIFT, 8, movetoworkspace, 8"
        "$mainMod SHIFT, 9, movetoworkspace, 9"
        "$mainMod SHIFT, 0, movetoworkspace, 10"

        "$mainMod SHIFT, H, movetoworkspace, e-1"
        "$mainMod SHIFT, L, movetoworkspace, e+1"
        "$mainMod SHIFT, left, movetoworkspace, e-1"
        "$mainMod SHIFT, right, movetoworkspace, e+1"

        # Example special workspace (scratchpad)
        "$mainMod, S, togglespecialworkspace, magic"
        "$mainMod SHIFT, S, movetoworkspace, special:magic"

        # Scroll through existing workspaces with mainMod + scroll
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"
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
        "$mainMod, PRINT, exec, hyprshot -z -m output"
        "$mainMod SHIFT, PRINT, exec, hyprshot -z -m window"
      ];
      bindm = [
        # Move/resize windows with mainMod + LMB/RMB and dragging
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      windowrulev2 =
        let
          floatingWindowRules = class: [
            "float, initialClass:${class}"
            "center, initialClass:${class}"
            "size 60% 60%, initialClass:${class}"
          ];
        in
        lib.lists.flatten [
          (floatingWindowRules "1Password")
          (floatingWindowRules "io.github.Qalculate.qalculate-qt")
        ];

      xwayland = {
        force_zero_scaling = true;
      };

    };
  };

  programs.fuzzel = {
    enable = true;
    settings = {
      "border" = {
        "width" = 3;
      };
    };
  };

  services.swaync = {
    enable = true;
  };

}
