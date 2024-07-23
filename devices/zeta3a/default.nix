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

  # Initrd
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "uas" "usb_storage" "sd_mod" "amdgpu" ];

  # Networking
  networking.hostName = "zeta3a";
  networking.hostId = "f174c9ca";

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
      pools = [ "rpool" ];
    };
    autoSnapshot = {
      enable = true;
      frequent = 8;
      monthly = 1;
    };
  };

  # Filesystems

  fileSystems."/" =
    { device = "rpool/nixos";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

  # TODO
  #fileSystems."/boot" =
  #  { device = "/dev/disk/by-uuid/AE42-EF0B";
  #    fsType = "vfat";
  #  };

  fileSystems."/backup" =
    { device = "rpool/backup";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

  fileSystems."/nix" =
    { device = "rpool/nixos/nix";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

  fileSystems."/home" =
    { device = "rpool/userdata/home";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

  fileSystems."/root" =
    { device = "rpool/userdata/home/root";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

  fileSystems."/home/ross" =
    { device = "rpool/userdata/home/ross";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };

  fileSystems."/mnt/games" =
    { device = "/dev/disk/by-uuid/38022704-1140-4687-b1b0-d31bd490d17d";
      fsType = "ext4";
    };

  # Users
  home-manager.users.ross.xdg.configFile."kanshi/config".source = ./config/kanshi/config;
}
