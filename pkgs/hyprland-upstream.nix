{
  inputs,
  pkgs,
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  upstream = inputs.hyprland.packages.${system};
in
{
  aquamarine = inputs.hyprland.inputs.aquamarine.packages.${system}.aquamarine;
  hyprland = upstream.hyprland;

  xdg-desktop-portal-hyprland = upstream.xdg-desktop-portal-hyprland;
}
