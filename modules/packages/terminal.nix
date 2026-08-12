{
  pkgs,
  ...
}:

{
  # Register zsh system-wide and make it the default login shell.
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # Keep privileged machine-administration tools in the system profile so they
  # remain available through sudo's restricted PATH. User tools live in Home
  # Manager under home/packages/terminal.nix.
  environment.systemPackages = with pkgs; [
    hwinfo
    lshw
    traceroute
    atop
    iftop
    iotop
    sysdig
    perf
    exfatprogs
    linuxConsoleTools
    caligula
  ];

  # Preserve root-level scheduled cleanup without installing nh into the system
  # profile; Home Manager owns the interactive command and default flake.
  programs.nh = {
    package = pkgs.nh-cachix;
    clean.enable = true;
    clean.extraArgs = "--keep-since 10d";
  };

  virtualisation = {
    docker = {
      enable = true;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };

      daemon.settings.insecure-registries = [ "192.168.1.244:5000" ];
    };
    podman = {
      enable = true;
      autoPrune.enable = true;
    };
  };

  programs._1password.enable = true;
}
