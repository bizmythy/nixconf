{
  config,
  lib,
  pkgs,
  vars,
  ...
}:
let
  cfg = config.wm.hyprreposwitch;

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
        --set HYPRREPOSWITCH_REPO_ROOT ${cfg.repoRoot} \
        --set HYPRREPOSWITCH_REPO_PREFIX ${cfg.repoPrefix} \
        --set HYPRREPOSWITCH_REMOTE ${cfg.remote} \
        --set HYPRREPOSWITCH_STATE_PATH ${cfg.statePath} \
        --set HYPRREPOSWITCH_TERMINAL_CMD ${cfg.terminalCommand} \
        --set HYPRREPOSWITCH_EDITOR_CMD ${cfg.editorCommand} \
        --set HYPRREPOSWITCH_TERMINAL_CLASSES ${lib.concatStringsSep "," cfg.terminalClasses} \
        --set HYPRREPOSWITCH_EDITOR_CLASSES ${lib.concatStringsSep "," cfg.editorClasses}
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
