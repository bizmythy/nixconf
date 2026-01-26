{
  description = "Nixos config flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";

    # set up config files and user settings
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # secrets management through 1Password
    opnix.url = "github:brizzbuzz/opnix";

    # catppuccin theming for all applications
    catppuccin.url = "github:catppuccin/nix";

    # flakpak installation management
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    # latest zen browser, patched over prebuilt firefox
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # precompiled AI tools
    nix-ai-tools.url = "github:numtide/nix-ai-tools";

    # neovim configured in nix
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # work configuration modules
    dirac = {
      type = "git";
      url = "ssh://git@dirac-github/diracq/buildos-web.git";
      ref = "main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    systems.url = "github:nix-systems/default";
    # formatter
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    { nixpkgs, self, ... }@inputs:
    let
      lib = nixpkgs.lib;

      # Small tool to iterate over each systems
      eachSystem = f: lib.genAttrs (import inputs.systems) (system: f nixpkgs.legacyPackages.${system});

      # Eval the treefmt modules from ./treefmt.nix
      treefmtEval = eachSystem (pkgs: inputs.treefmt-nix.lib.evalModule pkgs ./treefmt.nix);

      buildConfig = builtins.fromJSON (builtins.readFile ./build_config.json);

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
          tty = "kitty";
          fileManager = "dolphin";
          browser = "zen-beta";
          calculator = "qalculate-qt";
          editor = "zeditor";
          termEditor = "nvim";
          shell = "nu";
        };

        # function that will give whether the config refers to a personal machine
        isPersonal = config: !(lib.strings.hasInfix "dirac" config.networking.hostName);
      };

      nixpkgsSettings = {
        # Allow unfree packages
        config.allowUnfree = true;
        overlays = [
          (import ./overlays.nix { inherit inputs; })
        ];
      };

      home = {
        home-manager = {
          extraSpecialArgs = { inherit inputs vars; };
          backupFileExtension = vars.hmBackupFileExtension;
          users."${vars.user}" = {
            nixpkgs = nixpkgsSettings;
            imports = [
              inputs.opnix.homeManagerModules.default
              inputs.catppuccin.homeModules.catppuccin
              inputs.nixvim.homeModules.nixvim
              ./home
            ];

          };
        };
      };

      getPcConfig =
        hostname:
        lib.nixosSystem {
          specialArgs = { inherit inputs vars; };
          modules = [
            {
              nixpkgs = nixpkgsSettings // {
                hostPlatform = "x86_64-linux";
              };
              networking.hostName = hostname;
            }

            inputs.catppuccin.nixosModules.catppuccin
            inputs.nix-flatpak.nixosModules.nix-flatpak
          ]
          # conditionally include dirac module (set vars.enableDirac = false when bootstrapping)
          ++ lib.optionals buildConfig.flags.enableDirac [
            inputs.dirac.nixosModules.linux
            ./dirac.nix
          ]
          ++ [
            # my nixos configuration
            ./modules/base.nix
            ./hosts/${hostname}/configuration.nix

            # home-manager module and my home-manager config
            inputs.home-manager.nixosModules.home-manager
            home
          ];
        };

      pcConfigs = lib.genAttrs buildConfig.hosts getPcConfig;

      getServerConfig =
        hostname:
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs vars; };
          modules = [
            {
              nixpkgs = nixpkgsSettings // {
                hostPlatform = "x86_64-linux";
              };
              networking.hostName = hostname;
            }

            ./modules/server.nix
            ./hosts/${hostname}/configuration.nix
          ];
        };

      serverConfigs = lib.genAttrs [
        "nixos-0"
      ] getServerConfig;

      configs = pcConfigs // serverConfigs;
    in
    {
      nixosConfigurations = configs;

      packages = eachSystem (pkgs: {
        nvim = inputs.nixvim.legacyPackages.${pkgs.stdenv.hostPlatform.system}.makeNixvim (
          import ./nixvim.nix { inherit pkgs; }
        );
      });

      formatter = eachSystem (pkgs: treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.wrapper);

      checks = eachSystem (pkgs: {
        formatting = treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.check self;
      });
    };
}
