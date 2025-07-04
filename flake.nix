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

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dirac = {
      type = "git";
      url = "ssh://git@dirac-github/diracq/buildos-web.git";
      ref = "main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      # determinate,
      catppuccin,
      nix-flatpak,
      dirac,
      home-manager,
      treefmt-nix,
      ...
    }@inputs:
    let
      vars = rec {
        user = "drew";
        home = "/home/${user}";
        flakePath = "${home}/nixconf";
        hmBackupFileExtension = "hmbackup";
        lockScreenPic = builtins.fetchurl {
          url = "https://filedn.com/l0xkAHTdfcEJNc2OW7dfBny/lockscreen.png";
          sha256 = "1w3biszx1iy9qavr2cvl4gxrlf3lbrjpp50bp8wbi3rdpzjgv4kl";
        };
        defaults = {
          tty = "alacritty";
          fileManager = "dolphin";
          browser = "zen";
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

      # Small tool to iterate over each systems
      eachSystem = f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});

      # Eval the treefmt modules from ./treefmt.nix
      treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
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

      formatter = eachSystem (pkgs: treefmtEval.${pkgs.system}.config.build.wrapper);

      checks = eachSystem (pkgs: {
        formatting = treefmtEval.${pkgs.system}.config.build.check self;
      });
    };
}
