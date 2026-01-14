{ config, lib, ... }: {
  name = "ross";
  home = "/home/ross";
  extraGroups = [ "wheel" "docker" "games" "input" "video" "dialout" ];
  isNormalUser = true;
  initialPassword = "nixos";
}
