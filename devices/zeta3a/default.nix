{ config, pkgs, lib, ... }:
{
  imports = [
    ../../system/linux/desktop.nix
  ];

  # Bootloader
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = true;
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.devNodes = "/dev/";
  boot.kernelPackages = pkgs.linuxPackages_6_8;

  # Initrd
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "uas" "usb_storage" "sd_mod" "amdgpu" ];

  # Networking
  networking.hostName = "zeta3a";
  networking.hostId = "f174c9ca";

  services.openssh.enable = true;

  # Graphics
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "amdgpu" ];

  hardware.opengl.driSupport = true;

  # Services
  services.irqbalance.enable = true;
  services.ananicy.enable = true;

  services.zfs = {
    trim = {
      enable = true;
    };
    autoScrub = {
      enable = true;
      pools = [ "zpool" ];
    };
    autoSnapshot = {
      enable = true;
      frequent = 8;
      monthly = 1;
    };
  };

  # Filesystems

  fileSystems."/" =
    { device = "zpool/root";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-label/boot";
      fsType = "vfat";
    };

  fileSystems."/nix" =
    { device = "zpool/nix";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

  fileSystems."/home" =
    { device = "zpool/home";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

  fileSystems."/var" =
    { device = "zpool/var";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

  # Users
  home-manager.users.ross.xdg.configFile."kanshi/config".source = ./config/kanshi/config;
}