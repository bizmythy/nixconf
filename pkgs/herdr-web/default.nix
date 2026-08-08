{
  buildNpmPackage,
  lib,
  makeWrapper,
  nerd-fonts,
  nodejs,
}:

let
  terminalSettings = import ../../home/tty/settings.nix;
  webTheme = builtins.toJSON terminalSettings.webTheme;
  fontDir = "${nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono";
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
            document.fonts.load('${toString terminalSettings.fontSize}px "${terminalSettings.fontFamily}"'),
          ]);
        ''} \
      --replace-fail "fontFamily: 'JetBrains Mono, Menlo, Monaco, monospace'," \
        "fontFamily: ${lib.escapeShellArg terminalSettings.fontFamily}," \
      --replace-fail "fontSize: 14," \
        ${lib.escapeShellArg ''
          fontSize: ${toString terminalSettings.fontSize},
          scrollback: ${toString terminalSettings.scrollback},
          cursorStyle: 'bar',
          cursorBlink: false,
        ''} \
      --replace-fail "foreground: '#d4d4d4'," \
        ${lib.escapeShellArg "foreground: '#d4d4d4', ...${webTheme},"} \
      --replace-fail "    </style>" ${lib.escapeShellArg ''
          @font-face {
            font-family: '${terminalSettings.fontFamily}';
            src: url('/dist/JetBrainsMonoNerdFont-Regular.ttf') format('truetype');
            font-style: normal;
            font-weight: normal;
          }
          @font-face {
            font-family: '${terminalSettings.fontFamily}';
            src: url('/dist/JetBrainsMonoNerdFont-Bold.ttf') format('truetype');
            font-style: normal;
            font-weight: bold;
          }
          @font-face {
            font-family: '${terminalSettings.fontFamily}';
            src: url('/dist/JetBrainsMonoNerdFont-Italic.ttf') format('truetype');
            font-style: italic;
            font-weight: normal;
          }
          @font-face {
            font-family: '${terminalSettings.fontFamily}';
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
