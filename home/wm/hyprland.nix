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
      ];

      general = {
        "col.active_border" = "$accent";
        "gaps_in" = 5;
        "gaps_out" = 10;
      };

      decoration = {
        "rounding" = 14;
      };

      "$mainMod" = "SUPER";

      "$terminal" = "alacritty";
      "$fileManager" = "dolphin";
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
      ];
      bindm = [
        # Move/resize windows with mainMod + LMB/RMB and dragging
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];
      gestures = {
        workspace_swipe = true;
        workspace_swipe_fingers = 3;
      };

      windowrulev2 =
        let
          floatingWindowRules = class: [
            "float, initialClass:${class}"
            "center, initialClass:${class}"
            "size 50% 50%, initialClass:${class}"
          ];
        in
        lib.lists.flatten [
          (floatingWindowRules "1Password")
          (floatingWindowRules "io.github.Qalculate.qalculate-qt")
        ];
    };
  };

  programs.fuzzel = {
    enable = true;
  };

  services.swaync = {
    enable = true;
  };

}
