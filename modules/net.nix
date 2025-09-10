{ config, ... }:
{
  security.rtkit.enable = true;

  services.resolved.enable = true;

  networking = {
    networkmanager.enable = !config.networking.wireless.enable;
    firewall.checkReversePath = "loose";
  };
}
