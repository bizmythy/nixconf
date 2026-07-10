# AI plan-usage widgets for waybar: claudebar/codexbar consumed from upstream
# (github.com/mryll), grokbar is our companion script for pi's grok-cli account.
{
  pkgs,
  lib,
  ...
}:

let
  runtimeDeps = with pkgs; [
    coreutils
    curl
    gnused
    jq
    util-linux # flock
  ];

  mkUsageBar =
    {
      pname,
      version,
      hash,
    }:
    pkgs.stdenvNoCC.mkDerivation {
      inherit pname version;
      src = pkgs.fetchFromGitHub {
        owner = "mryll";
        repo = pname;
        tag = "v${version}";
        inherit hash;
      };
      nativeBuildInputs = [ pkgs.makeWrapper ];
      dontBuild = true; # upstream Makefile installs to /usr/local
      installPhase = ''
        runHook preInstall
        install -Dm755 ${pname} $out/bin/${pname}
        wrapProgram $out/bin/${pname} --prefix PATH : ${lib.makeBinPath runtimeDeps}
        runHook postInstall
      '';
      meta.license = lib.licenses.mit;
    };

  claudebar = mkUsageBar {
    pname = "claudebar";
    version = "0.8.1";
    hash = "sha256-te/ktnawRkHbUlENTmy/FS6eLCWXVzzr3od/2v9S7ow=";
  };

  codexbar = mkUsageBar {
    pname = "codexbar";
    version = "0.6.0";
    hash = "sha256-n0XwchPZTE3xnPK+ZXDetXpD/WsmZI/eHxHQfjBwiyU=";
  };

  grokbar = pkgs.writeShellApplication {
    name = "grokbar";
    runtimeInputs = runtimeDeps;
    bashOptions = [
      "nounset"
      "pipefail"
    ];
    text = builtins.readFile ./grokbar.sh;
  };

  ai-usagebar = pkgs.writeShellApplication {
    name = "ai-usagebar";
    runtimeInputs = runtimeDeps ++ [
      claudebar
      codexbar
      grokbar
    ];
    bashOptions = [
      "nounset"
      "pipefail"
    ];
    text = builtins.readFile ./ai-usagebar.sh;
  };
in
{
  home.packages = [
    ai-usagebar
    claudebar
    codexbar
    grokbar
  ];
}
