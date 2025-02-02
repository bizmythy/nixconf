{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      catppuccin,
      home-manager,
      ...
    }@inputs:
    {
      nixosConfigurations = {
        xps = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            catppuccin.nixosModules.catppuccin
            ./hosts/xps/configuration.nix

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                backupFileExtension = "backup";
                users.drew = {
                  imports = [
                    ./home.nix
                    catppuccin.homeManagerModules.catppuccin
                  ];
                };
              };
            }

          ];
        };
      };
    };
}
