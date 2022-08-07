{ pkgs, nixpkgs-unstable, ... }:

{
  lib.computer-guy.tokyonight-gtk-themes = pkgs.callPackage ./data/themes/tokyonight {};
  lib.computer-guy.eww-wayland = pkgs.callPackage ./applications/window-managers/eww { withWayland = true; };
}
