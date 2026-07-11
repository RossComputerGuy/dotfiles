{ config, lib, ... }:
{
  name = "ross";
  home = "/home/ross";
  extraGroups = [
    "wheel"
    "docker"
    "games"
    "input"
    "video"
    "dialout"
    "plugdev"
  ];
  isNormalUser = true;
  initialPassword = "nixos";
}
