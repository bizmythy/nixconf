{
  lib,
  pkgs,
}:
{
  arguments ? [ ],
  displayName,
  expectedFailure,
  package,
  program,
  settings,
}:
let
  configFile = (pkgs.formats.yaml { }).generate "${program}-config-validation.yml" settings;
  executable = lib.getExe package;
  validator = pkgs.writers.writeNuBin "validate-lazy-app-config" (
    builtins.readFile ./lazy-app-validate.nu
  );
in
lib.hm.dag.entryBefore [ "writeBoundary" ] ''
  run ${lib.getExe validator} ${
    lib.escapeShellArgs (
      [
        displayName
        "programs.${program}.settings"
        configFile
        executable
        (lib.getExe' pkgs.util-linux "setsid")
        expectedFailure
      ]
      ++ arguments
    )
  }
''
