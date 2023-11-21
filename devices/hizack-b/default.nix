{ config, lib, pkgs, ... }:
{
  imports = [
    ../../system/linux/desktop.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  virtualisation.waydroid.enable = true;

  boot.binfmt = {
    emulatedSystems = [
      "x86_64-linux"
      "i386-linux"
    ];
  };

  boot.kernelPatches = [{
    name = "waydroid";
    patch = null;
    extraConfig = ''
      ANDROID_BINDER_IPC y
      ANDROID_BINDERFS y
      ANDROID_BINDER_DEVICES binder,hwbinder,vndbinder
      ASHMEM y
      ANDROID_BINDERFS y
      ANDROID_BINDER_IPC y
    '';
  }];

  programs.firefox.enable = true;

  hardware.bluetooth.enable = true;
  networking = {
    hostName = "hizack-b";
    wireless = {
      enable = false;
      iwd.enable = true;
    };
    networkmanager.wifi.backend = "iwd";
  };

  hardware.asahi = {
    extractPeripheralFirmware = true;
    peripheralFirmwareDirectory = ./firmware;
    useExperimentalGPUDriver = true;
    addEdgeKernelConfig = true;
  };

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
