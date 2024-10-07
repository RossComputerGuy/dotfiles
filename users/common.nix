{ lib, pkgs, ... }@args:
with lib;
let
  inherit (pkgs.targetPlatform) parsed;
in
rec {
  importHome = user: 
    recursiveUpdate (import ./${user}/home.nix args)
      (import ./${user}/home-${parsed.kernel.name}.nix args);

  importUser = user:
    recursiveUpdate (import ./${user}/default.nix args)
      (import ./${user}/default-${parsed.kernel.name}.nix args);

  usernames = [ "ross" ];
  homes = builtins.listToAttrs (builtins.attrValues
    (builtins.mapAttrs (key: value: {
      name = value.home.username;
      inherit value;
    }) (genAttrs usernames importHome)));

  users = builtins.listToAttrs (builtins.attrValues
    (builtins.mapAttrs (key: value: {
      inherit (value) name;
      inherit value;
    }) (genAttrs usernames importUser)));
}
