{ config, lib, pkgs, ... }@args:
with lib;
with import ./common.nix args;
{
  imports = [
    ./home.nix
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  users.users = users;
}
