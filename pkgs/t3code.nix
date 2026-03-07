{
  lib,
  stdenv,
  fetchFromGitHub,
  bun,
  copyDesktopItems,
  electron_40,
  makeDesktopItem,
  makeWrapper,
  nodejs,
  python3,
  writableTmpDirAsHomeHook,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "t3code";
  version = "0.0.3";
  rev = "04b95e37c582c81c3fd67748dcae40f4b0a56b90";

  src = fetchFromGitHub {
    owner = "pingdotgg";
    repo = "t3code";
    rev = finalAttrs.rev;
    hash = "sha256-OGrm4PaXBE6vCx8ynfnsdPnOrc6JqHXiKc1liEh0HCU=";
  };

  nodeModules = stdenv.mkDerivation {
    pname = "${finalAttrs.pname}-node-modules";
    inherit (finalAttrs) src version;

    impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
      "GIT_PROXY_COMMAND"
      "SOCKS_SERVER"
    ];

    nativeBuildInputs = [
      bun
      writableTmpDirAsHomeHook
    ];

    dontConfigure = true;
    dontFixup = true;

    buildPhase = ''
      runHook preBuild

      export BUN_INSTALL_CACHE_DIR="$(mktemp -d)"

      bun install \
        --frozen-lockfile \
        --ignore-scripts \
        --linker=hoisted \
        --no-progress

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      cp -R ./node_modules "$out"

      runHook postInstall
    '';

    outputHash = "sha256-mEf8d3BihR3ezvzFCidLjcajEVAjHZOEo8/Vl3aIGlo=";
    outputHashMode = "recursive";
  };

  nativeBuildInputs = [
    bun
    copyDesktopItems
    makeWrapper
    nodejs
    python3
    writableTmpDirAsHomeHook
  ];

  buildPhase = ''
    runHook preBuild

    cp -R ${finalAttrs.nodeModules} node_modules
    chmod -R u+w node_modules
    patchShebangs node_modules

    export npm_config_nodedir=${nodejs}
    npm rebuild node-pty --foreground-scripts

    bun run build:desktop

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    local app_root="$out/lib/t3code"

    mkdir -p \
      "$app_root/apps/desktop" \
      "$app_root/apps/server" \
      "$app_root/packages" \
      "$out/bin"

    cp -R apps/desktop/dist-electron "$app_root/apps/desktop/"
    cp -R apps/desktop/resources "$app_root/apps/desktop/"
    cp -R apps/server/dist "$app_root/apps/server/"
    cp -R apps/web "$app_root/apps/"
    cp -R apps/marketing "$app_root/apps/"
    cp -R packages/contracts "$app_root/packages/"
    cp -R packages/shared "$app_root/packages/"
    cp -R scripts "$app_root/"
    cp -R node_modules "$app_root/"

    cat > "$app_root/package.json" <<EOF
    {
      "name": "t3code",
      "version": "${finalAttrs.version}",
      "main": "apps/desktop/dist-electron/main.js",
      "t3codeCommitHash": "${finalAttrs.rev}"
    }
    EOF

    install -Dm644 apps/desktop/resources/icon.png \
      "$out/share/icons/hicolor/512x512/apps/t3code.png"

    makeWrapper ${lib.getExe electron_40} "$out/bin/t3code" \
      --add-flags "$app_root"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "t3code";
      desktopName = "T3 Code";
      exec = "t3code %U";
      icon = "t3code";
      startupWMClass = "T3 Code (Alpha)";
      categories = [ "Development" ];
      keywords = [
        "AI"
        "Code"
        "Electron"
      ];
    })
  ];

  meta = {
    description = "Desktop app for T3 Code";
    homepage = "https://github.com/pingdotgg/t3code";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "t3code";
    platforms = lib.platforms.linux;
  };
})
