{
  inputs,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

  services.fwupd.enable = true;

  # Keep encrypted SSDs fast under Docker/build churn: pass TRIM and skip dm-crypt queues.
  boot.initrd.luks.devices."luks-50172681-d606-4c2f-935f-bbd3dbfba257" = {
    allowDiscards = true;
    bypassWorkqueues = true;
  };

  hardware.graphics.extraPackages = with pkgs; [
    rocmPackages.clr.icd
  ];

  environment.systemPackages = with pkgs; [
    amd-ctk
    amd-container-runtime
  ];
  virtualisation.docker.daemon.settings.runtimes.amd = {
    path = lib.getExe pkgs.amd-container-runtime;
  };

  services.ollama = {
    enable = false;
    openFirewall = true;
    # environmentVariables = {
    #   OLLAMA_MODELS = "/mnt/storage/ollama";
    # };
  };
}
