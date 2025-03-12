{
  pkgs,
  ...
}:
# https://nixos.wiki/wiki/1Password
let
  # onePassPath = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  onePassPath = "~/.1password/agent.sock";
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
  '';
}
