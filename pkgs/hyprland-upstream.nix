{
  inputs,
  pkgs,
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  upstream = inputs.hyprland.packages.${system};
  upstreamAquamarine = inputs.hyprland.inputs.aquamarine.packages.${system}.aquamarine;
  aquamarine = upstreamAquamarine.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./aquamarine-no-forced-color-state-on-modeset.patch
    ];
  });
in
{
  inherit aquamarine;

  hyprland = upstream.hyprland.override {
    inherit aquamarine;
  };

  xdg-desktop-portal-hyprland = upstream.xdg-desktop-portal-hyprland;
}
