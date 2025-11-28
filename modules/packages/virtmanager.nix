{
  pkgs,
  vars,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    # tpm emulation for windows VM
    swtpm
  ];

  programs.virt-manager.enable = true;

  users.groups.libvirtd.members = [ vars.user ];
  virtualisation = {
    libvirtd.enable = true;
    spiceUSBRedirection.enable = true;
  };
}
