{
  pkgs,
  vars,
  ...
}:
let
  genKeyFile =
    name: value:
    pkgs.writeTextFile {
      name = "${name}.pub";
      text = value;
    };

  publicKeys = {
    personalGitHub = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOjbUnES0AUVvsqNzMdCix3Qp+XRpKiS7tm6PR6u7WTY";
    diracGitHub = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIrRXpZt/U8OkMsWoft9+2JiITBsUyGVxuhZJhl+Xpm";
    diraclocalserver = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEoZXGhcmj8ZUFPWWGw3fZAd0FOCZKXnKelZKaGD9Tq4";
    hetzner = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGogIJ4uaReEMnM8eRedZh0OVq/4AAs4H8xdiWjvf6YF";
  };
  publicKeyFiles = builtins.mapAttrs genKeyFile publicKeys;

  onePassPath = "${vars.home}/.1password/agent.sock";
in
{
  # -------SSH CONFIGURATION-------
  # home manager version adds several extra options i do not want
  # set github.com to be dirac key by default to get private flake inputs working
  # this default is replaced in the git ssh command configuration
  home.file.".ssh/config".text = ''
    Host dirac-github
        HostName github.com
        User git
        IdentityFile ${publicKeyFiles.diracGitHub}
        IdentitiesOnly yes
        IdentityAgent ${onePassPath}

    Host diraclocalserver
        HostName 192.168.1.244
        User diraclocalserver
        IdentityFile ${publicKeyFiles.diraclocalserver}
        IdentityAgent ${onePassPath}

    Host hetzner
        HostName 178.156.186.220
        IdentityFile ${publicKeyFiles.hetzner}
        IdentityAgent ${onePassPath}

    Host *
        IdentityAgent ${onePassPath}
  '';

  # You can test the available keys and their order of attempt by running:
  #  SSH_AUTH_SOCK=~/.1password/agent.sock ssh-add -l
  xdg.configFile."1Password/ssh/agent.toml".text =
    builtins.readFile (
      (pkgs.formats.toml { }).generate "1Password-ssh-agent.toml" {
        "ssh-keys" = map (item: { inherit item; }) [
          "wtjniyvaszfbfdt567snocygqq" # dirac github
          "tf64ipw7poybpzazfzz3geyefu" # personal github
          "te6zz2ycolprvsfedj4iqd3jja" # diraclocalserver
          "av5h4r2kyfwueck7e7jq7gw5cu" # hetzner
        ];
      }
    )
    + "\n"; # needs to end with newline or we get strange undefined behavior

  # delta for git diff viewer
  programs.delta = {
    enable = true;
    options = {
      side-by-side = false;
    };
    enableGitIntegration = true;
  };

  # git configuration
  programs.git =
    let
      # configuration for each git account
      personalConfig = {
        user = {
          name = "bizmythy";
          email = "andrew.p.council@gmail.com";
          signingkey = publicKeys.personalGitHub;
        };
        core.sshCommand = "ssh -i ${publicKeyFiles.personalGitHub}";
      };
      diracConfig = {
        user = {
          name = "drew-dirac";
          email = "drew@diracinc.com";
          signingkey = publicKeys.diracGitHub;
        };
        core.sshCommand = "ssh -i ${publicKeyFiles.diracGitHub}";
      };
    in
    {
      enable = true;
      lfs.enable = true;
      settings = {
        # preferences
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
        core.hooksPath = ".githooks";
        core.editor = vars.defaults.termEditor;

        # 1password ssh commit signing
        gpg.format = "ssh";
        # should be declared deterministically, but can't get same pkg as in nixos config
        "gpg \"ssh\"".program = "/run/current-system/sw/bin/op-ssh-sign";
        commit.gpgsign = true;
      }
      // personalConfig; # set default to personal

      includes = [
        # dirac-specific git setup
        # need to `git init` in ~/dirac for this to work properly
        {
          condition = "gitdir:${vars.home}/dirac/";
          contentSuffix = ".dirac.gitconfig";
          contents = diracConfig; # apply dirac in this condition
        }
      ];
    };
}
