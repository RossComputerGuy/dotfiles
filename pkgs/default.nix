{ pkgs ? import <nixpkgs> {} }: with pkgs;

rec {
  tokyonight-gtk-themes = callPackage ./data/themes/tokyonight {};
}
