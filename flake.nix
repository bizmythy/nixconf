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
      };
    in
    {
      nixosConfigurations = {
        xps = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs vars; };
          modules = [
            catppuccin.nixosModules.catppuccin
            nix-flatpak.nixosModules.nix-flatpak
            ./hosts/xps/configuration.nix

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                extraSpecialArgs = { inherit vars; };
                backupFileExtension = "bak";
                users.drew = {
                  imports = [
                    catppuccin.homeManagerModules.catppuccin
                    ./home/home.nix
                  ];
                };
              };
            }
          ];
        };
        igneous = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs vars; };
          modules = [
            catppuccin.nixosModules.catppuccin
            nix-flatpak.nixosModules.nix-flatpak
            ./hosts/igneous/configuration.nix

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                extraSpecialArgs = { inherit vars; };
                backupFileExtension = "bak";
                users.drew = {
                  imports = [
                    catppuccin.homeManagerModules.catppuccin
                    ./home/home.nix
                  ];
                };
              };
            }
          ];
        };
        drewdirac = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs vars; };
          modules = [
            catppuccin.nixosModules.catppuccin
            nix-flatpak.nixosModules.nix-flatpak
            ./hosts/drewdirac/configuration.nix

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                extraSpecialArgs = { inherit vars; };
                backupFileExtension = "bak";
                users.drew = {
                  imports = [
                    catppuccin.homeManagerModules.catppuccin
                    ./home/home.nix
                  ];
                };
              };
            }
          ];
        };
      };
    };
}
