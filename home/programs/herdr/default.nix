{
  config,
  lib,
  pkgs,
  ...
}:

let
  toml = pkgs.formats.toml { };
  keybindsPlugin = pkgs.callPackage ./keybinds-plugin/package.nix { };
  pluginId = "drew.herdr-keybinds";
  pluginDir = "herdr/plugins/${pluginId}";
  manifestPath = "${config.xdg.configHome}/${pluginDir}/herdr-plugin.toml";
  actionCommand = subcommand: arg: [
    (lib.getExe keybindsPlugin)
    subcommand
    arg
  ];
  setupCommand = [
    (lib.getExe keybindsPlugin)
    "setup-workspace"
  ];
  manifest = toml.generate "herdr-keybinds-plugin.toml" {
    id = pluginId;
    name = "Drew Herdr Keybinds";
    version = "0.1.0";
    min_herdr_version = "0.7.0";
    description = "Directional pane, tab, and workspace navigation for Herdr.";
    platforms = [ "linux" ];

    actions = [
      {
        id = "navigate-left";
        title = "Navigate left";
        contexts = [
          "pane"
          "tab"
          "workspace"
        ];
        command = actionCommand "navigate" "left";
      }
      {
        id = "navigate-down";
        title = "Navigate down";
        contexts = [
          "pane"
          "tab"
          "workspace"
        ];
        command = actionCommand "navigate" "down";
      }
      {
        id = "navigate-up";
        title = "Navigate up";
        contexts = [
          "pane"
          "tab"
          "workspace"
        ];
        command = actionCommand "navigate" "up";
      }
      {
        id = "navigate-right";
        title = "Navigate right";
        contexts = [
          "pane"
          "tab"
          "workspace"
        ];
        command = actionCommand "navigate" "right";
      }
      {
        id = "focus-git";
        title = "Focus git tab";
        contexts = [
          "pane"
          "tab"
          "workspace"
        ];
        command = actionCommand "focus-tab" "git";
      }
      {
        id = "focus-ws";
        title = "Focus ws tab";
        contexts = [
          "pane"
          "tab"
          "workspace"
        ];
        command = actionCommand "focus-tab" "ws";
      }
      {
        id = "setup-workspace";
        title = "Set up default workspace tabs";
        contexts = [
          "pane"
          "tab"
          "workspace"
        ];
        command = setupCommand;
      }
    ];

    events = [
      {
        on = "workspace.created";
        command = setupCommand;
      }
    ];
  };
in

{
  xdg.configFile."herdr/config.toml".source = toml.generate "herdr-config.toml" (import ./config.nix);
  xdg.configFile."${pluginDir}/herdr-plugin.toml".source = manifest;

  home.activation.herdrKeybindsPlugin = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    manifest=${lib.escapeShellArg manifestPath}
    if [ -e "$manifest" ]; then
      if ! ${lib.getExe pkgs.herdr} plugin link "$manifest" >/dev/null; then
        echo "warning: failed to link Herdr keybinds plugin" >&2
      fi
    fi
  '';
}
