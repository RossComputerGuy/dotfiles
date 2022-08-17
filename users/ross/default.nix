{ config, pkgs, ... }:
{
  users.users.ross = {
    isNormalUser = true;
    home = "/home/ross";
    description = "Tristan Ross";
    extraGroups = [ "wheel" "docker" "adbusers" "games" "input" ];
  };

  home-manager.users.ross = import ./home-linux.nix { inherit pkgs; inherit config; };
}
