let
  scaleHiDPI = 1.5;

  # Primary edit surface: define monitors/profile intent per host here.
  hosts = {
    drewdiracpc = {
      monitors = {
        main = {
          desc = "Samsung Electric Company U32J59x HCJXA01635";
          workspace = 2;
          settings = {
            mode = "3840x2160";
            position = "0x0";
            scale = scaleHiDPI;
          };
        };
        right = {
          desc = "LG Electronics LG SDQHD 409NTTQ8K433";
          workspace = 1;
          settings = {
            mode = "2560x2880@60";
            position = "auto-right";
            scale = 1.333333;
          };
        };
        top = {
          desc = "Acer Technologies KA272 TJ0AA00785SJ";
          workspace = 8;
          settings = {
            mode = "1920x1080@60";
            position = "575x-1080";
            scale = 1.0;
          };
        };
      };
    };

    igneous = {
      monitors = {
        main = {
          desc = "Microstep MSI MAG322UPF";
          workspace = 2;
          settings = {
            mode = "3840x2160@160";
            position = "0x0";
            scale = scaleHiDPI;
            vrr = 0;
          };
        };
        top = {
          desc = "ViewSonic Corporation VX2418-P FHD WFK231321682";
          workspace = 1;
          settings = {
            mode = "1920x1080@60";
            position = "575x-1080";
            scale = 1.0;
          };
        };
        tv = {
          desc = "LG Electronics LG TV SSCR2 0x01010101";
          workspace = 10;
          settings = {
            mode = "3840x2160@120";
            position = "auto-right";
            scale = scaleHiDPI;
          };
        };
      };

      profiles = {
        dnd = {
          enabledOutputs = [ "tv" ];
          useTablet = true;
        };
        tv = {
          enabledOutputs = [ "tv" ];
          useTablet = false;
        };
        desktop = {
          enabledOutputs = [
            "main"
            "top"
          ];
          useTablet = false;
        };
      };
    };

    theseus = {
      monitors = {
        laptop = {
          desc = "BOE 0x095F";
          settings = {
            mode = "preferred";
            position = "auto-down";
            scale = 1.566667;
          };
        };
      };

      profiles = {
        "1080p" = {
          enabledOutputs = [ "laptop" ];
          useTablet = false;
          monitorOverrides = {
            laptop = {
              mode = "1920x1080";
              scale = scaleHiDPI;
            };
          };
        };
        tablet = {
          enabledOutputs = [ "laptop" ];
          useTablet = true;
        };
      };
    };
  };

  outputFromDesc = desc: "desc:${desc}";
  outputFromMonitor = monitor: outputFromDesc monitor.desc;

  resolveOutput =
    monitorDefs: outputRef:
    let
      ref = toString outputRef;
    in
    if builtins.hasAttr ref monitorDefs then
      outputFromMonitor monitorDefs.${ref}
    else if builtins.match "desc:.*" ref != null then
      ref
    else
      outputFromDesc ref;

  monitorSettingsForHost =
    hostConfig:
    map (monitor: monitor.settings // { output = outputFromMonitor monitor; }) (
      builtins.attrValues hostConfig.monitors
    );

  workspaceRulesForHost =
    hostConfig:
    let
      monitorsWithWorkspace = builtins.concatLists (
        map (
          monitorName:
          let
            monitor = hostConfig.monitors.${monitorName};
          in
          if monitor ? workspace && monitor.workspace != null then
            [
              {
                workspace = monitor.workspace;
                output = outputFromMonitor monitor;
              }
            ]
          else
            [ ]
        ) (builtins.attrNames hostConfig.monitors)
      );
      sortedMonitors = builtins.sort (a: b: a.workspace < b.workspace) monitorsWithWorkspace;
    in
    map (
      monitor: "${toString monitor.workspace}, monitor:${monitor.output}, default:true"
    ) sortedMonitors;

  monitorOverridesForProfile =
    monitorDefs: monitorOverrides:
    builtins.listToAttrs (
      map (outputRef: {
        name = resolveOutput monitorDefs outputRef;
        value = monitorOverrides.${outputRef};
      }) (builtins.attrNames monitorOverrides)
    );

  profilesForHost =
    hostConfig:
    let
      profileDefs = hostConfig.profiles or { };
    in
    map (
      profileKey:
      let
        profile = profileDefs.${profileKey};
      in
      {
        key = profileKey;
        label = profile.label or profileKey;
        enabledOutputs = map (
          outputRef: resolveOutput hostConfig.monitors outputRef
        ) profile.enabledOutputs;
        useTablet = profile.useTablet or false;
      }
      // (
        if profile ? monitorOverrides then
          {
            monitorOverrides = monitorOverridesForProfile hostConfig.monitors profile.monitorOverrides;
          }
        else
          { }
      )
    ) (builtins.attrNames profileDefs);

  defaultLayoutsByHost = builtins.mapAttrs (_: hostConfig: {
    monitorv2 = monitorSettingsForHost hostConfig;
    workspaces = workspaceRulesForHost hostConfig;
  }) hosts;

  hyprmonitorProfilesByHost = builtins.mapAttrs (_: hostConfig: profilesForHost hostConfig) hosts;

  monitors = builtins.mapAttrs (
    _: hostConfig: builtins.mapAttrs (_: monitor: outputFromMonitor monitor) hostConfig.monitors
  ) hosts;

  tabletHeadless = {
    name = "HEADLESS-TABLET";
    width = 2560;
    height = 1600;
    downsample = 2;
    scale = 1.0;
    position = "auto-left";
  };
in
{
  inherit
    defaultLayoutsByHost
    hosts
    hyprmonitorProfilesByHost
    monitors
    tabletHeadless
    ;

  monitorv2 = builtins.concatLists (
    map (host: defaultLayoutsByHost.${host}.monitorv2) (builtins.attrNames defaultLayoutsByHost)
  );

  workspaceByHost = builtins.mapAttrs (_: value: value.workspaces) defaultLayoutsByHost;
}
