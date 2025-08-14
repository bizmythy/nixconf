{
  pkgs,
  lib,
  ...
}:
let
  # import all files in the ./src directory as scripts
  scriptDir = ./src;
  scriptFileNames = builtins.attrNames (builtins.readDir scriptDir);

  # make a script with binary name based on script name
  getName = filename: builtins.elemAt (lib.splitString "." filename) 0;
  getPath = filename: scriptDir + "/${filename}";
  makeScript =
    filename: pkgs.writeScriptBin (getName filename) (builtins.readFile (getPath filename));
in
{
  home.packages = map makeScript scriptFileNames;
}
