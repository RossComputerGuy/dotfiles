{ home-manager, pkgs, expr, ... }:
let
  ross = import ./ross { inherit home-manager; inherit pkgs; inherit expr; };
in
{
  home-manager.users.ross = ross.homeManager;
  users.users.ross = ross.useradd;
}
