{ config, pkgs, ... }:
{
  imports = [
    ../../users/default.nix
  ];

  security.expidus.enable = false;

  time.timeZone = "America/Los_Angeles";
  systemd.enableUnifiedCgroupHierarchy = true;

  # Virtualization
  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;

  # Network Configuration
  security.rtkit.enable = true;

  services.resolved.enable = true;
  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "systemd-resolved";
  networking.firewall.checkReversePath = "loose";

  services.resolved.extraConfig = ''
    DNS=192.168.1.41
    DNS=100.82.207.123
    DNS=8.8.8.8
    DNS=8.8.4.4
    DNSOverTLS=yes
  '';

  # Keyboard & Input

  i18n.defaultLocale = "ja_JP.UTF-8";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "ja_JP.UTF-8/UTF-8" ];

  # Packages
  services.fwupd.enable = true;
  services.udisks2.enable = true;
  programs.git.enable = true;

  environment.systemPackages = with pkgs; [
    lm_sensors
    fwupd-efi
  ];
}
