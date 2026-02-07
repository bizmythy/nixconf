let
  scaleHiDPI = 1.5;

  monitors = {
    igneous = {
      main = "desc:Microstep MSI MAG322UPF";
      top = "desc:ViewSonic Corporation VX2418-P FHD WFK231321682";
      tv = "desc:LG Electronics LG TV SSCR2 0x01010101";
    };
    drewdirac = {
      main = "desc:Samsung Electric Company U32J59x HCJXA01635";
      right = "desc:LG Electronics LG SDQHD 409NTTQ8K433";
      top = "desc:Acer Technologies KA272 TJ0AA00785SJ";
    };
    theseus = {
      laptop = "desc:BOE 0x095F";
    };
  };

  defaultLayoutsByHost = {
    drewdiracpc = {
      monitorv2 = [
        {
          output = monitors.drewdirac.main;
          mode = "3840x2160";
          position = "0x0";
          scale = scaleHiDPI;
        }
        {
          output = monitors.drewdirac.right;
          mode = "2560x2880@60";
          position = "auto-right";
          scale = 1.333333;
        }
        {
          output = monitors.drewdirac.top;
          mode = "1920x1080@60";
          position = "575x-1080";
          scale = 1.0;
        }
      ];
      workspaces = [
        "1, monitor:${monitors.drewdirac.right}, default:true"
        "2, monitor:${monitors.drewdirac.main}, default:true"
        "8, monitor:${monitors.drewdirac.top}, default:true"
      ];
    };
    igneous = {
      monitorv2 = [
        {
          output = monitors.igneous.main;
          mode = "3840x2160@160";
          position = "0x0";
          scale = scaleHiDPI;
          vrr = 0;
        }
        {
          output = monitors.igneous.top;
          mode = "1920x1080@60";
          position = "575x-1080";
          scale = 1.0;
        }
        {
          output = monitors.igneous.tv;
          mode = "3840x2160@120";
          position = "auto-right";
          scale = scaleHiDPI;
        }
      ];
      workspaces = [
        "1, monitor:${monitors.igneous.top}, default:true"
        "2, monitor:${monitors.igneous.main}, default:true"
        "10, monitor:${monitors.igneous.tv}, default:true"
      ];
    };
    theseus = {
      monitorv2 = [
        {
          output = monitors.theseus.laptop;
          mode = "preferred";
          position = "auto-down";
          scale = 1.566667;
        }
      ];
      workspaces = [ ];
    };
  };

  hyprmonitorProfilesByHost = {
    igneous = [
      {
        key = "dnd";
        label = "DnD";
        enabledOutputs = [ monitors.igneous.tv ];
        useTablet = true;
      }
      {
        key = "tv";
        label = "TV";
        enabledOutputs = [ monitors.igneous.tv ];
        useTablet = false;
      }
      {
        key = "desktop";
        label = "Desktop";
        enabledOutputs = [
          monitors.igneous.main
          monitors.igneous.top
        ];
        useTablet = false;
      }
    ];
    theseus = [
      {
        key = "tablet";
        label = "Tablet";
        enabledOutputs = [ monitors.theseus.laptop ];
        useTablet = true;
      }
    ];
  };

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
  inherit defaultLayoutsByHost hyprmonitorProfilesByHost monitors tabletHeadless;

  monitorv2 = builtins.concatLists (
    map (host: defaultLayoutsByHost.${host}.monitorv2) (builtins.attrNames defaultLayoutsByHost)
  );

  workspaceByHost = builtins.mapAttrs (_: value: value.workspaces) defaultLayoutsByHost;
}
