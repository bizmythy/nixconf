{
  inputs,
  pkgs,
}:
let
  upstream = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  hyprland = upstream.hyprland.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./hyprland-reset-monitor-format-on-rule.patch
    ];
  });

  xdg-desktop-portal-hyprland = upstream.xdg-desktop-portal-hyprland;
}
