{
  lib,
  stdenv,
  fetchFromGitHub,
  makeWrapper,
  bash,
  bc,
  coreutils,
  ffmpeg,
  gawk,
  gnugrep,
  gnused,
  ollama,
  pipewire,
  procps,
  python3,
  wl-clipboard,
  xclip,
}:
let
  rev = "9a53cbad3adfdf55a2bf44d469a8e3475c3bdeb6";
  pythonEnv = python3.withPackages (ps: [ ps.faster-whisper ]);
  runtimePath = lib.makeBinPath [
    bash
    bc
    coreutils
    ffmpeg
    gawk
    gnugrep
    gnused
    ollama
    pipewire
    procps
    wl-clipboard
    xclip
  ];
in
stdenv.mkDerivation rec {
  pname = "xhisper-local";
  version = "unstable-${lib.substring 0 7 rev}";

  src = fetchFromGitHub {
    owner = "wpbryant";
    repo = "xhisper-local";
    inherit rev;
    hash = "sha256-keYX3+kKaKHyaNMzuXRKuSlayE66m85sSoAm/SmQmTk=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    $CC -O2 -Wall -Wextra xhispertool.c -o xhispertool
    ln -s xhispertool xhispertoold

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 xhispertool $out/bin/xhispertool
    ln -s xhispertool $out/bin/xhispertoold

    install -Dm755 xhisper.sh $out/bin/xhisper
    install -Dm644 xhisper_transcribe.py $out/libexec/xhisper_transcribe.py
    install -Dm644 default_xhisperrc $out/share/xhisper-local/default_xhisperrc

    substituteInPlace $out/bin/xhisper \
      --replace-fail 'export LD_LIBRARY_PATH=/usr/local/lib/ollama/cuda_v12/lib:$LD_LIBRARY_PATH' "" \
      --replace-fail 'TRANSCRIPT_SCRIPT="$SCRIPT_DIR/xhisper_transcribe.py"' 'TRANSCRIPT_SCRIPT="$SCRIPT_DIR/xhisper_transcribe"' \
      --replace-fail 'local transcription=$(python3 "$TRANSCRIPT_SCRIPT" "$recording" $cmd_args 2>/dev/null)' 'local transcription=$("$TRANSCRIPT_SCRIPT" "$recording" $cmd_args 2>/dev/null)'

    patchShebangs $out/bin/xhisper $out/libexec/xhisper_transcribe.py

    makeWrapper ${pythonEnv}/bin/python $out/bin/xhisper_transcribe \
      --add-flags "$out/libexec/xhisper_transcribe.py"

    wrapProgram $out/bin/xhisper \
      --prefix PATH : "$out/bin:${runtimePath}"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Linux dictation tool with local Whisper transcription and optional Ollama formatting";
    homepage = "https://github.com/wpbryant/xhisper-local";
    license = licenses.mit;
    mainProgram = "xhisper";
    platforms = platforms.linux;
  };
}
