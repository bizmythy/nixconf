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
    { self, nixpkgs, ... }@inputs:
    {
      nixosConfigurations = {
        xps = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            catppuccin.nixosModules.catppuccin
            ./hosts/xps/configuration.nix
            inputs.home-manager.nixosModules.default
          ];
        };
      };
    };
}
