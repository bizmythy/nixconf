rec {
  fontFamily = "JetBrainsMono Nerd Font";
  fontSize = 12;
  backgroundOpacity = 0.9;
  scrollback = 10000;

  # Catppuccin Mocha. Keep this palette here so native Ghostty and
  # ghostty-web render the same terminal colors.
  colors = {
    background = "1e1e2e";
    foreground = "cdd6f4";
    cursor = "f5e0dc";
    cursorAccent = "11111b";
    selectionBackground = "353749";
    selectionForeground = "cdd6f4";
    palette = [
      "45475a"
      "f38ba8"
      "a6e3a1"
      "f9e2af"
      "89b4fa"
      "f5c2e7"
      "94e2d5"
      "a6adc8"
      "585b70"
      "f38ba8"
      "a6e3a1"
      "f9e2af"
      "89b4fa"
      "f5c2e7"
      "94e2d5"
      "bac2de"
    ];
  };

  webTheme =
    let
      addHash = color: "#${color}";
      palette = map addHash colors.palette;
    in
    {
      background = addHash colors.background;
      cursor = addHash colors.cursor;
      cursorAccent = addHash colors.cursorAccent;
      foreground = addHash colors.foreground;
      selectionBackground = addHash colors.selectionBackground;
      selectionForeground = addHash colors.selectionForeground;
      black = builtins.elemAt palette 0;
      red = builtins.elemAt palette 1;
      green = builtins.elemAt palette 2;
      yellow = builtins.elemAt palette 3;
      blue = builtins.elemAt palette 4;
      magenta = builtins.elemAt palette 5;
      cyan = builtins.elemAt palette 6;
      white = builtins.elemAt palette 7;
      brightBlack = builtins.elemAt palette 8;
      brightRed = builtins.elemAt palette 9;
      brightGreen = builtins.elemAt palette 10;
      brightYellow = builtins.elemAt palette 11;
      brightBlue = builtins.elemAt palette 12;
      brightMagenta = builtins.elemAt palette 13;
      brightCyan = builtins.elemAt palette 14;
      brightWhite = builtins.elemAt palette 15;
    };
}
