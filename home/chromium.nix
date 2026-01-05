{
  lib,
  osConfig,
  ...
}:
{
  programs.chromium = {
    enable = true;
    commandLineArgs = lib.mkIf osConfig.nvidiaEnable [
      "--ozone-platform-hint=x11"
    ];
  };
}
