{ home-manager, pkgs, expr, dbus-sway-environment, lib, ... }:
{
  imports = [
    (import ./ross/desktop.nix { inherit pkgs; inherit home-manager; inherit expr; inherit dbus-sway-environment; inherit lib; })
  ];
}
