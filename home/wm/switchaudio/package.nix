{ pkgs }:
let
  sharedPythonLib = pkgs.writeTextDir "lib/nixconf_audio/__init__.py" (
    builtins.readFile ../../../nixconf_audio/__init__.py
  );
  rawScript = pkgs.writers.writePython3Bin "switchaudio" {
    libraries = [ ];
  } (builtins.readFile ./main.py);
in
pkgs.symlinkJoin {
  name = "switchaudio";
  paths = [
    rawScript
    sharedPythonLib
  ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  meta.mainProgram = "switchaudio";
  postBuild = ''
    wrapProgram "$out/bin/switchaudio" \
      --prefix PYTHONPATH : "$out/lib"
  '';
}
