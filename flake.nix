{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";

    nix-flatpak.url = "github:gmodena/nix-flatpak"; # unstable branch

    zen-browser.url = "github:0xc000022070/zen-browser-flake";
  };

  outputs =
    {
      self,
      nixpkgs,
      catppuccin,
      nix-flatpak,
      home-manager,
      ...
    }@inputs:
    let
      vars = {
        flakePath = "/home/drew/nixconf";
        hmBackupFileExtension = "hmbackup";
      };

      home = {
        home-manager = {
          extraSpecialArgs = { inherit vars; };
          backupFileExtension = vars.hmBackupFileExtension;
          users.drew = {
            imports = [
              catppuccin.homeManagerModules.catppuccin
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
            catppuccin.nixosModules.catppuccin
            nix-flatpak.nixosModules.nix-flatpak
            ./modules/base.nix
            ./hosts/${hostname}/configuration.nix
            { networking.hostName = hostname; }

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
    };
}
