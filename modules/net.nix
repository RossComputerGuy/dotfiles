{ config, lib, ... }:
{
  security.rtkit.enable = true;

  services.resolved.enable = true;

  networking.firewall.checkReversePath = "loose";
}
