{
  config,
  lib,
  ...
}:

{
  options.laptop = {
    enable = lib.mkEnableOption "laptop";
  };

  config = lib.mkIf config.laptop.enable {
    powerManagement = {
      enable = true;
      powertop.enable = true;
    };
  };
}
