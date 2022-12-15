{ config, lib, pkgs, ... }@args:
{
  imports = [
    ./home.nix
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  users.users.ross = import ./ross/default.nix args;
}
