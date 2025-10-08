{
  pkgs,
  ...
}:

{
  home.file.".codex/config.toml".text = builtins.readFile (
    (pkgs.formats.toml { }).generate "config.toml" {
      # hahaha i'm sure nothing will go wrong
      sandbox_mode = "danger-full-access";
    }
  );
}
