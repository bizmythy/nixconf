{
  lib,
  stdenv,
  fetchurl,
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
  whisperCpp,
  wl-clipboard,
  xclip,
}:
let
  upstreamRev = "9a53cbad3adfdf55a2bf44d469a8e3475c3bdeb6";
  whisperRuntime = whisperCpp.override {
    vulkanSupport = true;
    withSDL = false;
  };
  bundledModel = fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
    sha256 = "00nhqqvgwyl9zgyy7vk9i3n017q2wlncp5p7ymsk0cpkdp47jdx0";
  };
  bundledVadModel = fetchurl {
    url = "https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v6.2.0.bin";
    sha256 = "11v9zgvwkihs750kmdiswd49q7bwvwfm081sk213mdgfhnvnk8ia";
  };
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
  version = "unstable-${lib.substring 0 7 upstreamRev}";

  src = lib.cleanSourceWith {
    src = ../xhisper-local;
    filter =
      path: type:
      let
        baseName = builtins.baseNameOf (toString path);
      in
      !(baseName == ".git" || baseName == ".github");
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

    install -d $out/share/xhisper-local/models
    install -Dm755 xhispertool $out/bin/xhispertool
    ln -s xhispertool $out/bin/xhispertoold

    install -Dm755 xhisper.sh $out/bin/xhisper
    install -Dm755 xhisper_transcribe $out/bin/xhisper_transcribe
    install -Dm644 default_xhisperrc $out/share/xhisper-local/default_xhisperrc
    install -Dm644 ${bundledModel} $out/share/xhisper-local/models/ggml-base.en.bin
    install -Dm644 ${bundledVadModel} $out/share/xhisper-local/models/ggml-silero-v6.2.0.bin

    patchShebangs $out/bin/xhisper $out/bin/xhisper_transcribe

    wrapProgram $out/bin/xhisper_transcribe \
      --prefix PATH : "${
        lib.makeBinPath [
          coreutils
          gnused
        ]
      }" \
      --set XHISPER_WHISPER_CLI "${whisperRuntime}/bin/whisper-cli" \
      --set XHISPER_MODEL_PATH "$out/share/xhisper-local/models/ggml-base.en.bin" \
      --set XHISPER_VAD_MODEL_PATH "$out/share/xhisper-local/models/ggml-silero-v6.2.0.bin" \
      --set XHISPER_GPU_DEVICE "0"

    wrapProgram $out/bin/xhisper \
      --prefix PATH : "$out/bin:${runtimePath}"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Linux dictation tool with local whisper.cpp transcription and optional Ollama formatting";
    homepage = "https://github.com/wpbryant/xhisper-local";
    license = licenses.mit;
    mainProgram = "xhisper";
    platforms = platforms.linux;
  };
}
