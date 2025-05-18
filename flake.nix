{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    zen-browser.url = "github:0xc000022070/zen-browser-flake";

    dirac = {
      type = "git";
      url = "ssh://git@dirac-github/diracq/buildos-web.git";
      ref = "main";
      shallow = true;
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      # determinate,
      catppuccin,
      nix-flatpak,
      dirac,
      home-manager,
      ...
    }@inputs:
    let
      vars = rec {
        user = "drew";
        home = "/home/${user}";
        flakePath = "${home}/nixconf";
        hmBackupFileExtension = "hmbackup";
        lockScreenPic = nixpkgs.fetchurl {
          url = "https://filedn.com/l0xkAHTdfcEJNc2OW7dfBny/lockscreen.png";
          sha256 = "14bd14bbwi295q95jm3sff8j4rs5xpf5qpffczmqshf54hgm35kz";
        };
        defaults = {
          tty = "ghostty";
          fileManager = "dolphin";
          browser = "firefox";
          calculator = "qalculate-qt";
          editor = "zeditor";
          termEditor = "nvim";
          shell = "nu";
        };
      };

      home = {
        home-manager = {
          extraSpecialArgs = { inherit vars; };
          backupFileExtension = vars.hmBackupFileExtension;
          users."${vars.user}" = {
            imports = [
              catppuccin.homeModules.catppuccin
              ./home/home.nix
            ];
          };
        };
      };

      hostConfig =
        hostname:
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs vars; };
          modules = [
            {
              nixpkgs.hostPlatform = "x86_64-linux";
              networking.hostName = hostname;
            }

            # dirac config already sets this
            # determinate.nixosModules.default
            catppuccin.nixosModules.catppuccin
            nix-flatpak.nixosModules.nix-flatpak

            dirac.nixosModules.linux
            {
              dirac.graphical = false;
              # override what i am already managing in home manager
              programs = {
                direnv.enable = false;
                git.enable = nixpkgs.lib.mkForce false;
                starship.enable = false;
              };
            }

            ./modules/base.nix
            ./hosts/${hostname}/configuration.nix

            home-manager.nixosModules.home-manager
            home
          ];
        };
    in
    {
      nixosConfigurations = builtins.listToAttrs (
        map
          (hostname: {
            name = hostname;
            value = hostConfig hostname;
          })
          [
            "xps"
            "igneous"
            "theseus"
            "drewdirac"
            "drewdiracpc"
          ]
      );

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-rfc-style;
    };
}
