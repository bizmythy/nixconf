{
  pkgs,
  ...
}:

{
  catppuccin.waybar = {
    enable = true;
    mode = "createLink";
  };

  programs.waybar = {
    enable = true;
    package = pkgs.waybar.overrideAttrs (old: {
      src = pkgs.fetchFromGitHub {
        owner = "Alexays";
        repo = "Waybar";
        rev = "05945748dccce28bf96d26d8f64a9e69a8dd49ba";
        hash = "sha256-51R3mIt8cLNvh/X5qe9vOqeJCj0U9KRyemVE5y+OhiU=";
      };
      mesonFlags = (builtins.filter (flag: flag != "-Dcava=enabled") old.mesonFlags) ++ [
        "-Dcava=disabled"
      ];
    });
    style = ./waybar.css;
    settings.mainBar = {
      # "layer" = "top"; # Waybar at top layer
      # "position" = "bottom"; # Waybar position (top|bottom|left|right)
      height = 10; # Waybar height (to be removed for auto height)
      # "width" = 1280; # Waybar width
      spacing = 4; # Gaps between modules (4px)
      # Choose the order of the modules
      modules-left = [
        "hyprland/workspaces"
        # "custom/media"
      ];
      modules-center = [
        "hyprland/window"
      ];
      modules-right = [
        "mpd"
        "pulseaudio"
        "battery"
        "battery#bat2"
        "tray"
        "custom/notification"
        "clock"
        "custom/power"
      ];
      # Modules configuration
      "hyprland/workspaces" = {
        disable-scroll = true;
        all-outputs = true;
        warp-on-scroll = false;
        # format = "{name}: {icon}";
        # format-icons = {
        #   1 = ""
        #   2 = ""
        #   3 = ""
        #   4 = ""
        #   5 = ""
        #   urgent = ""
        #   focused = ""
        #   default = ""
        # };
      };
      "keyboard-state" = {
        numlock = true;
        capslock = true;
        format = "{name} {icon}";
        format-icons = {
          locked = "";
          unlocked = "";
        };
      };

      mpd = {
        format = "{stateIcon} {consumeIcon}{randomIcon}{repeatIcon}{singleIcon}{artist} - {album} - {title} ({elapsedTime:%M:%S}/{totalTime:%M:%S}) ⸨{songPosition}|{queueLength}⸩ {volume}% ";
        format-disconnected = "Disconnected ";
        format-stopped = "{consumeIcon}{randomIcon}{repeatIcon}{singleIcon}Stopped ";
        unknown-tag = "N/A";
        interval = 5;
        consume-icons = {
          on = " ";
        };
        random-icons = {
          off = "<span color=\"#f53c3c\"></span> ";
          on = " ";
        };
        repeat-icons = {
          on = " ";
        };
        single-icons = {
          on = "1 ";
        };
        state-icons = {
          paused = "";
          playing = "";
        };
        tooltip-format = "MPD (connected)";
        tooltip-format-disconnected = "MPD (disconnected)";
      };

      idle_inhibitor = {
        format = "{icon}";
        format-icons = {
          activated = "";
          deactivated = "";
        };
      };

      tray = {
        # icon-size = 21;
        spacing = 10;
      };

      clock = {
        format = "{:%I:%M}"; # 12-hour format
        # timezone = "America/New_York";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        format-alt = "{:%Y-%m-%d}";
      };

      cpu = {
        format = "{usage}% ";
        tooltip = false;
      };

      memory = {
        format = "{}% ";
      };

      temperature = {
        # thermal-zone = 2;
        # hwmon-path = "/sys/class/hwmon/hwmon2/temp1_input";
        critical-threshold = 80;
        # format-critical = "{temperatureC}°C {icon}";
        format = "{temperatureC}°C {icon}";
        format-icons = [
          ""
          ""
          ""
        ];
      };

      backlight = {
        format = "{percent}% {icon}";
        format-icons = [
          ""
          ""
          ""
          ""
          ""
          ""
          ""
          ""
          ""
        ];
      };

      battery = {
        states = {
          # good = 95;
          warning = 30;
          critical = 15;
        };
        format = "{capacity}% {icon}";
        format-full = "{capacity}% {icon}";
        format-charging = "{capacity}% ";
        format-plugged = "{capacity}% ";
        format-alt = "{time} {icon}";
        # format-good = ""; # An empty format will hide the module
        # format-full = "";
        format-icons = [
          ""
          ""
          ""
          ""
          ""
        ];
      };

      "battery#bat2" = {
        bat = "BAT2";
      };

      power-profiles-daemon = {
        format = "{icon}";
        tooltip-format = "Power profile: {profile}\nDriver: {driver}";
        tooltip = true;
        format-icons = {
          default = "";
          performance = "";
          balanced = "";
          power-saver = "";
        };
      };

      network = {
        # interface = "wlp2*"; # (Optional) To force the use of this interface
        format-wifi = "{essid} ";
        format-ethernet = "{ipaddr}/{cidr} ";
        tooltip-format = "{ifname} via {gwaddr}";
        format-linked = "{ifname} (No IP) ";
        format-disconnected = "Disconnected ⚠";
        # format-alt = "{ifname}: {ipaddr}/{cidr} ({signalStrength}%)";
        on-click = "nm-connection-editor";
      };

      bluetooth = {
        format = " {status}";
        format-disabled = ""; # an empty format will hide the module
        format-connected = " {num_connections}";
        tooltip-format = "{device_alias}";
        tooltip-format-connected = " {device_enumerate}";
        tooltip-format-enumerate-connected = "{device_alias}";
        on-click = "blueman-manager";
      };

      pulseaudio = {
        scroll-step = 5; # %, can be a float
        format = "{volume}% {icon} {format_source}";
        format-bluetooth = "{volume}% {icon} {format_source}";
        # format-bluetooth-muted = " {icon} {format_source}";
        # format-muted = " {format_source}";
        format-source = "";
        format-source-muted = "";
        format-icons = {
          headphone = "";
          phone = "";
          portable = "";
          car = "";
          default = [
            ""
            ""
            ""
          ];
        };
        on-click = "switchaudio";
        on-click-right = "pavucontrol";
      };

      "custom/media" = {
        format = "{icon} {text}";
        return-type = "json";
        max-length = 40;
        format-icons = {
          spotify = "";
          default = "🎜";
        };
        escape = true;
        # exec = "$HOME/.config/waybar/mediaplayer.py 2> /dev/null";
        # exec = "$HOME/.config/waybar/mediaplayer.py --player spotify 2> /dev/null"; # Filter player based on name
      };

      "custom/notification" = {
        tooltip = false;
        format = "{icon}";
        format-icons = {
          notification = "<span foreground='red'><sup></sup></span> ";
          none = " ";
          dnd-notification = "<span foreground='red'><sup></sup></span> ";
          dnd-none = " ";
          inhibited-notification = "<span foreground='red'><sup></sup></span> ";
          inhibited-none = " ";
          dnd-inhibited-notification = "<span foreground='red'><sup></sup></span> ";
          dnd-inhibited-none = " ";
        };
        return-type = "json";
        exec-if = "which swaync-client";
        exec = "swaync-client -swb";
        on-click = "swaync-client -t -sw";
        on-click-right = "swaync-client -d -sw";
        escape = true;
      };

      "custom/power" = {
        format = "⏻ ";
        tooltip = false;
        menu = "on-click";
        menu-file = "${./power_menu.xml}";
        menu-actions = {
          shutdown = "poweroff";
          reboot = "reboot";
          suspend = "systemctl suspend";
          hibernate = "systemctl hibernate";
        };
      };
    };
  };
}
