{
  lib,
  stdenv,
  runCommand,
  writeShellApplication,
  fetchFromGitHub,
  topiary,
}:
let
  topiaryNushellRev = "6e2f9b339a664a46e4015fa5d79e537807fefa39";
  topiaryNushellSrc = fetchFromGitHub {
    owner = "blindFS";
    repo = "topiary-nushell";
    rev = topiaryNushellRev;
    sha256 = "1xr0y5yih2xpl1njbjqjmph4j51wlrlghhq8plx3dva8fm5g2dvx";
  };

  treeSitterNuRev = "f4793e3809bb84e78dee260b47085d8203a58d88";
  treeSitterNuSrc = fetchFromGitHub {
    owner = "nushell";
    repo = "tree-sitter-nu";
    rev = treeSitterNuRev;
    sha256 = "1nqzr8ay6sgbkp8mpabcc6zjmavsnxhrhxidmdlvzlxwp000xm6j";
  };

  treeSitterNu = stdenv.mkDerivation {
    pname = "tree-sitter-nu";
    version = treeSitterNuRev;
    src = treeSitterNuSrc;

    makeFlags = [ "PREFIX=$(out)" ];

    meta = {
      description = "Tree-sitter grammar for Nushell";
      homepage = "https://github.com/nushell/tree-sitter-nu";
      license = lib.licenses.mit;
    };
  };

  topiaryConfigDir = runCommand "topiary-nushell-config" { } ''
    mkdir -p "$out/queries"
    cp ${topiaryNushellSrc}/queries/nu.scm "$out/queries/nu.scm"

    cat > "$out/languages.ncl" <<EOF
    {
      languages = {
        nu = {
          extensions | default = ["nu"],
          grammar.source | default = {
            path = "${treeSitterNu}/lib/libtree-sitter-nu${stdenv.hostPlatform.extensions.sharedLibrary}",
          },
        },
      },
    }
    EOF
  '';
in
writeShellApplication {
  name = "topiary-nushell";
  runtimeInputs = [ topiary ];
  runtimeEnv = {
    TOPIARY_CONFIG_FILE = "${topiaryConfigDir}/languages.ncl";
    TOPIARY_LANGUAGE_DIR = "${topiaryConfigDir}/queries";
  };
  text = ''
    exec ${lib.getExe topiary} format "$@"
  '';

  meta = {
    description = "Nushell formatter powered by Topiary and topiary-nushell";
    homepage = "https://github.com/blindFS/topiary-nushell";
    license = lib.licenses.mit;
    mainProgram = "topiary-nushell";
  };
}
