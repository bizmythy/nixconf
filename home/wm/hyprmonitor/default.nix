{
  pkgs,
  ...
}:
let
  monitorConfig = import ../monitor-config.nix;
  devices = builtins.attrNames monitorConfig.hyprmonitorProfilesByHost;
  configFile = pkgs.writeText "hyprmonitor-config.json" (
    builtins.toJSON {
      defaultLabel = "Default";
      tabletHeadless = monitorConfig.tabletHeadless;
      devices = builtins.listToAttrs (
        map (device: {
          name = device;
          value = {
            defaultSettings = monitorConfig.defaultLayoutsByHost.${device}.monitorv2;
            profiles = monitorConfig.hyprmonitorProfilesByHost.${device};
          };
        }) devices
      );
    }
  );
  rawScript = pkgs.writers.writePython3Bin "hyprmonitor" {
    libraries = with pkgs.python3Packages; [
      click
      hyprpy
    ];
  } (builtins.readFile ./main.py);
  script = pkgs.symlinkJoin {
    name = "hyprmonitor";
    paths = [ rawScript ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/hyprmonitor" \
        --set HYPRMONITOR_CONFIG_PATH ${configFile}
    '';
  };
in
{
  home.packages = [ script ];
}
