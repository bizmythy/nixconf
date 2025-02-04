{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin.url = "github:catppuccin/nix";

    stylix.url = "github:danth/stylix";
  };

  outputs =
    {
      self,
      nixpkgs,
      catppuccin,
      stylix,
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
            ./hosts/xps/configuration.nix

            home-manager.nixosModules.home-manager
            {
              home-manager = {
                extraSpecialArgs = { inherit vars; };
                backupFileExtension = "backuplog";
                users.drew = {
                  imports = [
                    stylix.homeManagerModules.stylix
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
