{
  config,
  lib,
  pkgs,
  ...
}@args:
with lib;
with import ./common.nix args;
{
  imports = [
    ./home.nix
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  # Home Manager refuses to replace a file it does not already own, which stops
  # activation dead. Firefox's profiles.ini is the first such file here. Move
  # the old one aside instead of aborting.
  home-manager.backupFileExtension = "hm-bak";

  users.users = users;
}
