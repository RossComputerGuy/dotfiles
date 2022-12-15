{ config, lib, pkgs, ... }@args:
with lib;
{
  home-manager.users = lib.genAttrs [ "ross" ] (user:
    mergeAttrs (import ./${user}/home.nix args)
      (import ./${user}/home-${pkgs.targetPlatform.parsed.kernel.name}.nix args));
}
