{
  inputs,
  lib,
  pkgs,
  vars,
  ...
}:
let
  isAndroid = vars.isAndroid or false;
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
  weavePackage = inputs.weave.packages.${pkgs.stdenv.hostPlatform.system}.default;
  weaveExtensions = [
    "ts"
    "tsx"
    "js"
    "mjs"
    "cjs"
    "jsx"
    "py"
    "go"
    "rs"
    "java"
    "c"
    "h"
    "cpp"
    "cc"
    "cxx"
    "hpp"
    "hh"
    "hxx"
    "rb"
    "cs"
    "php"
    "swift"
    "ex"
    "exs"
    "sh"
    "f90"
    "f95"
    "f03"
    "f08"
    "xml"
    "plist"
    "svg"
    "csproj"
    "fsproj"
    "vbproj"
    "json"
    "yaml"
    "yml"
    "toml"
    "md"
    "scala"
    "sc"
    "sbt"
    "kojo"
    "mill"
    "dart"
  ];
  weaveAttributes = map (extension: "*.${extension} merge=weave") weaveExtensions;
in
{
  home.packages = lib.optional (!isAndroid) weavePackage;

  # -------SSH CONFIGURATION-------
  # home manager version adds several extra options i do not want
  # set github.com to be dirac key by default to get private flake inputs working
  # this default is replaced in the git ssh command configuration
  home.file = lib.optionalAttrs (!isAndroid) {
    ".ssh/config".text = ''
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
          Port 52681
          User drew
          IdentityFile ${publicKeyFiles.hetzner}
          IdentityAgent ${onePassPath}

      Host igneous
          HostName 192.168.1.123
          User drew
          IdentityFile ${publicKeyFiles.hetzner}
          IdentitiesOnly yes
          IdentityAgent ${onePassPath}

        Host *
            IdentityAgent ${onePassPath}
    '';
  };

  # You can test the available keys and their order of attempt by running:
  #  SSH_AUTH_SOCK=~/.1password/agent.sock ssh-add -l
  xdg.configFile = lib.optionalAttrs (!isAndroid) {
    "1Password/ssh/agent.toml".text =
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
  };

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
      personalIdentity = {
        user = {
          name = "bizmythy";
          email = "andrew.p.council@gmail.com";
        };
      };
      personalConfig = lib.recursiveUpdate personalIdentity {
        user.signingkey = publicKeys.personalGitHub;
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
      attributes = lib.optionals (!isAndroid) weaveAttributes;
      lfs.enable = true;
      signing = lib.optionalAttrs (!isAndroid) {
        format = "ssh";
        # should be declared deterministically, but can't get same pkg as in nixos config
        signer = "/run/current-system/sw/bin/op-ssh-sign";
      };
      settings = {
        # preferences
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
        core.editor = vars.defaults.termEditor;

        # speed up large Git LFS uploads/downloads
        lfs = {
          # Default is 8; a modest increase tends to better saturate fast links.
          concurrenttransfers = 16;
          # Avoid restarting large transfers during brief idle/stall periods.
          activitytimeout = 60;
          # Use resumable uploads when the LFS server advertises tus.io support.
          tustransfers = true;
          transfer = {
            # Default is 100; fewer Batch API round trips for many LFS objects.
            batchSize = 256;
          };
        };

      }
      // lib.optionalAttrs (!isAndroid) {
        merge.weave = {
          name = "Entity-level semantic merge";
          driver = "weave-driver %O %A %B %L %P";
        };
        core.hooksPath = ".githooks";
        commit.gpgsign = true;
      }
      // (if isAndroid then personalIdentity else personalConfig); # set default to personal

      includes = lib.optionals (!isAndroid) [
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
