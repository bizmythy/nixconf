{
  pkgs,
  lib,
  ...
}:
let
  # import all files in the ./src directory as scripts
  scriptDir = ./src;
  scriptFileNames = builtins.attrNames (builtins.readDir scriptDir);
  scriptFilePaths = map (path: scriptDir + "/${path}") scriptFileNames;

  # make a script with binary name based on script name
  getName = path: builtins.elemAt (lib.splitString "." (builtins.baseNameOf path)) 0;
  makeScript = path: pkgs.writeScriptBin (getName path) (builtins.readFile path);
in
{
  home.packages = map makeScript scriptFilePaths;
}
