{ config, lib, pkgs, ... }@args:
with lib;
with import ./common.nix args;
{
  home-manager.users = homes;
}
