{
  pkgs,
  vars,
  ...
}:
{
  programs.virt-manager.enable = true;

  users.groups.libvirtd.members = [ vars.user ];
  # Temporary workaround for libvirt 12.1.0 shipping a systemd unit that
  # hardcodes /usr/bin/sh, which does not exist on NixOS.
  systemd.services.virt-secret-init-encryption = {
    overrideStrategy = "asDropin";
    serviceConfig.ExecStart = [
      ""
      "${pkgs.runtimeShell} -c 'umask 0077 && (${pkgs.coreutils}/bin/dd if=/dev/random status=none bs=32 count=1 | ${pkgs.systemd}/bin/systemd-creds encrypt --name=secrets-encryption-key - /var/lib/libvirt/secrets/secrets-encryption-key)'"
    ];
  };

  virtualisation = {
    libvirtd = {
      enable = true;
      qemu = {
        # enable software TPM emulation for Windows 11
        swtpm.enable = true;
      };
    };
    spiceUSBRedirection.enable = true;
  };
}
