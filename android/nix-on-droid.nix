{
  inputs,
  pkgs,
  vars,
  ...
}:
{
  environment.packages = with pkgs; [
    git
    openssh
    zsh
  ];
  environment.etcBackupExtension = ".bak";

  android-integration = {
    am.enable = true;
    termux-open.enable = true;
    termux-open-url.enable = true;
    termux-reload-settings.enable = true;
    termux-setup-storage.enable = true;
    termux-wake-lock.enable = true;
    termux-wake-unlock.enable = true;
    xdg-open.enable = true;
  };

  user.shell = "${pkgs.zsh}/bin/zsh";

  nix = {
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
    registry.nixpkgs.flake = inputs.nixpkgs;
  };

  home-manager = {
    backupFileExtension = vars.hmBackupFileExtension;
    config = ../home/android.nix;
    extraSpecialArgs = { inherit inputs vars; };
    sharedModules = [
      inputs.catppuccin.homeModules.catppuccin
      inputs.nix-index-database.homeModules.default
      inputs.nixvim.homeModules.nixvim
    ];
    useGlobalPkgs = true;
  };

  system.stateVersion = "24.05";
}
