{
  lib,
  osConfig,
  ...
}:
{
  programs.chromium = {
    enable = true;
    commandLineArgs = [
      "--remote-debugging-port=9222"
    ]
    ++ lib.optionals osConfig.nvidiaEnable [
      "--ozone-platform-hint=x11"
    ];
  };
}
