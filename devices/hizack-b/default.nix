{ config, lib, pkgs, ... }:
{
  imports = [
    ../../system/linux/desktop.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  hardware.bluetooth.enable = true;
  networking = {
    hostName = "hizack-b";
    wireless = {
      enable = false;
      iwd.enable = true;
    };
    networkmanager.wifi.backend = "iwd";
  };
  hardware.asahi.extractPeripheralFirmware = true;

  boot.extraModprobeConfig = ''
    options hid_apple iso_layout=0
  '';

  fileSystems."/" = {
    device = "/dev/nvme0n1p5";
    fsType = "ext4";
  };

  # Users
  home-manager.users.ross.xdg.configFile."eww/device.yuck".source = ./config/eww/device.yuck;
  home-manager.users.ross.xdg.configFile."sway/config.d/device.conf".source = ./config/sway/config.d/device.conf;
}
