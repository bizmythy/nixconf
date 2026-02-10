{
  config,
  lib,
  pkgs,
  vars,
  ...
}:
let
  cfg = config.wm.hyprreposwitch;
  configFile = pkgs.writeText "hyprreposwitch-config.json" (
    builtins.toJSON {
      repoRoot = cfg.repoRoot;
      repoPrefix = cfg.repoPrefix;
      remote = cfg.remote;
      statePath = cfg.statePath;
      terminalCommand = cfg.terminalCommand;
      editorCommand = cfg.editorCommand;
      terminalClasses = cfg.terminalClasses;
      editorClasses = cfg.editorClasses;
    }
  );

  rawScript = pkgs.writers.writePython3Bin "hyprreposwitch" {
    libraries = with pkgs.python3Packages; [
      click
      gitpython
      hyprpy
      textual
    ];
  } (builtins.readFile ./main.py);

  script = pkgs.symlinkJoin {
    name = "hyprreposwitch";
    paths = [ rawScript ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    meta.mainProgram = "hyprreposwitch";
    postBuild = ''
      wrapProgram "$out/bin/hyprreposwitch" \
        --set HYPRREPOSWITCH_CONFIG_PATH ${configFile}
    '';
  };
in
{
  options.wm.hyprreposwitch = {
    package = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "Packaged hyprreposwitch executable.";
    };

    repoRoot = lib.mkOption {
      type = lib.types.str;
      default = "${vars.home}/dirac";
      description = "Directory containing buildos-web repositories.";
    };

    repoPrefix = lib.mkOption {
      type = lib.types.str;
      default = "buildos-web";
      description = "Repository directory prefix for repo discovery and creation.";
    };

    remote = lib.mkOption {
      type = lib.types.str;
      default = "git@github.com:diracq/buildos-web.git";
      description = "Remote used to create/update the pristine repository.";
    };

    statePath = lib.mkOption {
      type = lib.types.str;
      default = "${vars.home}/.local/state/hyprreposwitch/state.json";
      description = "State file for currently active repo context.";
    };

    terminalCommand = lib.mkOption {
      type = lib.types.str;
      default = vars.defaults.tty;
      description = "Terminal command used for repo terminal workspace windows.";
    };

    editorCommand = lib.mkOption {
      type = lib.types.str;
      default = vars.defaults.editor;
      description = "Editor command used for repo editor workspace windows.";
    };

    terminalClasses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "kitty"
        "Alacritty"
        "foot"
        "Ghostty"
        "org.wezfurlong.wezterm"
      ];
      description = "Window classes recognized as terminal windows.";
    };

    editorClasses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "Zed"
        "dev.zed.Zed"
      ];
      description = "Window classes recognized as editor windows.";
    };
  };

  config = {
    wm.hyprreposwitch.package = script;
    home.packages = [ cfg.package ];
  };
}
