{
  config,
  pkgs,
  ...
}:

let
  yaml = pkgs.formats.yaml { };
in
{
  xdg.configFile."glow/glow.yml".source = yaml.generate "glow.yml" {
    style = "${config.catppuccin.sources.glamour}/catppuccin-${config.catppuccin.flavor}.json";
    width = 100;
  };
}
