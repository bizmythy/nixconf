{
  pkgs,
  ...
}:
# https://nixos.wiki/wiki/1Password
let
  # onePassPath = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  onePassPath = "~/.1password/agent.sock";

  diraclocalserverIdentityFile = pkgs.writeTextFile {
    name = "diraclocalserver.pub";
    text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEoZXGhcmj8ZUFPWWGw3fZAd0FOCZKXnKelZKaGD9Tq4";
  };
in
{
  # home manager version adds several extra options i do not want
  # programs.ssh = {
  #   enable = true;
  #   extraConfig = ''
  #     Host *
  #         IdentityAgent ${onePassPath}
  #   '';
  # };

  home.file.".ssh/config".text = ''
    Host *
        IdentityAgent ${onePassPath}

    Host diraclocalserver
        HostName 192.168.1.154
        User diraclocalserver
        IdentityAgent ${onePassPath}
        IdentityFile ${diraclocalserverIdentityFile}
        IdentitiesOnly yes
  '';

  xdg.configFile."1Password/ssh/agent.toml".text = ''
    [[ssh-keys]]
    vault = "Private"

    [[ssh-keys]]
    vault = "Employee"

    [[ssh-keys]]
    vault = "Engineering"
  '';
}
