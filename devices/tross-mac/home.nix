{ config, pkgs, ... }:
{
  imports = [
    ../../users/ross/home-darwin.nix
  ];

  home.username = "tristan";
  home.homeDirectory = "/Users/tristan";

  home.stateVersion = "22.05";
  programs.home-manager.enable = true;
}
