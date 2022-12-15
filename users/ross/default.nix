{ config, pkgs, ... }:
{
  isNormalUser = true;
  home = "/home/ross";
  description = "Tristan Ross";
  extraGroups = [ "wheel" "docker" "adbusers" "games" "input" "video" ];
  shell = pkgs.zsh;
}
