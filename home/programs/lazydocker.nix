{
  config,
  lib,
  pkgs,
  ...
}:
let
  mkLazyAppConfigValidation = import ./lazy-app-validation.nix { inherit lib pkgs; };
in
{
  programs.lazydocker = {
    enable = true;
    settings.gui = {
      returnImmediately = true;
      # catppuccin theme for lazydocker
      # theme = {
      #   activeBorderColor = [
      #     "#cba6f7"
      #     "bold"
      #   ];
      #   inactiveBorderColor = [
      #     "#a6adc8"
      #     "bold"
      #   ];
      #   selectedLineBgColor = [
      #     "default"
      #   ];
      #   optionsTextColor = [
      #     "#89b4fa"
      #     "bold"
      #   ];
      # };
    };
  };

  home.activation.validateLazydockerConfig = mkLazyAppConfigValidation {
    displayName = "Lazydocker";
    expectedFailure = "open /dev/tty: no such device or address";
    package = config.programs.lazydocker.package;
    program = "lazydocker";
    settings = config.programs.lazydocker.settings;
  };
}
