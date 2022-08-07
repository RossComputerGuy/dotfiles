{ pkgs, ... }:

{
  lib.computer-guy.tokyonight-gtk-themes = pkgs.callPackage ./data/themes/tokyonight {};
}
