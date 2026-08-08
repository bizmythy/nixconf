{
  buildNpmPackage,
  lib,
  makeWrapper,
  nerd-fonts,
  nodejs,
}:

let
  fontFamily = "JetBrainsMono Nerd Font";
  fontSize = 16;
  fontDir = "${nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono";
  webTheme = builtins.toJSON {
    background = "#1e1e2e";
    foreground = "#cdd6f4";
    cursor = "#f5e0dc";
    cursorAccent = "#11111b";
    selectionBackground = "#353749";
    selectionForeground = "#cdd6f4";
    black = "#45475a";
    red = "#f38ba8";
    green = "#a6e3a1";
    yellow = "#f9e2af";
    blue = "#89b4fa";
    magenta = "#f5c2e7";
    cyan = "#94e2d5";
    white = "#a6adc8";
    brightBlack = "#585b70";
    brightRed = "#f38ba8";
    brightGreen = "#a6e3a1";
    brightYellow = "#f9e2af";
    brightBlue = "#89b4fa";
    brightMagenta = "#f5c2e7";
    brightCyan = "#94e2d5";
    brightWhite = "#bac2de";
  };
in
buildNpmPackage {
  pname = "herdr-web";
  version = "0.1.0";

  src = ./.;
  npmDepsHash = "sha256-n1rcB5A5dfSQ/hPrqvtDm62inzFE38Va1eezuRi9WjQ=";

  dontNpmBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    demo="$PWD/node_modules/@ghostty-web/demo/bin/demo.js"
    dist="$PWD/node_modules/ghostty-web/dist"
    cp ${fontDir}/JetBrainsMonoNerdFont-{Regular,Bold,Italic,BoldItalic}.ttf "$dist/"

    substituteInPlace "$demo" \
      --replace-fail "await init();" \
        ${lib.escapeShellArg ''
          await Promise.all([
            init(),
            document.fonts.load('${toString fontSize}px "${fontFamily}"'),
          ]);
        ''} \
      --replace-fail "fontFamily: 'JetBrains Mono, Menlo, Monaco, monospace'," \
        ${lib.escapeShellArg ''fontFamily: '"${fontFamily}", monospace',''} \
      --replace-fail "fontSize: 14," \
        ${lib.escapeShellArg ''
          fontSize: ${toString fontSize},
          scrollback: 10000,
          cursorStyle: 'bar',
          cursorBlink: false,
        ''} \
      --replace-fail "foreground: '#d4d4d4'," \
        ${lib.escapeShellArg "foreground: '#d4d4d4', ...${webTheme},"} \
      --replace-fail "    </style>" ${lib.escapeShellArg ''
          @font-face {
            font-family: '${fontFamily}';
            src: url('/dist/JetBrainsMonoNerdFont-Regular.ttf') format('truetype');
            font-style: normal;
            font-weight: normal;
          }
          @font-face {
            font-family: '${fontFamily}';
            src: url('/dist/JetBrainsMonoNerdFont-Bold.ttf') format('truetype');
            font-style: normal;
            font-weight: bold;
          }
          @font-face {
            font-family: '${fontFamily}';
            src: url('/dist/JetBrainsMonoNerdFont-Italic.ttf') format('truetype');
            font-style: italic;
            font-weight: normal;
          }
          @font-face {
            font-family: '${fontFamily}';
            src: url('/dist/JetBrainsMonoNerdFont-BoldItalic.ttf') format('truetype');
            font-style: italic;
            font-weight: bold;
          }

          /* Make the terminal occupy the complete browser viewport. */
          body {
            min-height: 100dvh !important;
            padding: 0 !important;
          }
          .terminal-window {
            width: 100vw !important;
            max-width: none !important;
            height: 100dvh !important;
            border-radius: 0 !important;
          }
          .title-bar {
            display: none !important;
          }
          .terminal-content {
            height: 100dvh !important;
            padding: 0 !important;
          }
        </style>
      ''}

    mkdir -p "$out/lib/herdr-web" "$out/bin"
    cp -r node_modules "$out/lib/herdr-web/"
    makeWrapper ${lib.getExe nodejs} "$out/bin/herdr-web" \
      --add-flags "$out/lib/herdr-web/node_modules/@ghostty-web/demo/bin/demo.js"

    runHook postInstall
  '';

  meta = {
    description = "Fullscreen ghostty-web server for Herdr";
    homepage = "https://github.com/coder/ghostty-web";
    license = lib.licenses.mit;
    mainProgram = "herdr-web";
    platforms = lib.platforms.linux;
  };
}
