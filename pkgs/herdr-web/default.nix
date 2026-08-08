{
  buildNpmPackage,
  lib,
  makeWrapper,
  nodejs,
}:

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
    substituteInPlace "$demo" \
      --replace-fail "    </style>" ${lib.escapeShellArg ''
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
