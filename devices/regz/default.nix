{ config, ... }:
{
  imports = [
    ../../system/linux/desktop.nix
  ];

  # Bootloader
  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
    supportedFilesystems = [ "zfs" ];
    zfs.devNodes = "/dev/";
    extraModulePackages = with config.boot.kernelPackages; [ tt-kmd ];
    kernelModules = [ "tenstorrent" ];
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "ahci"
      "usbhid"
      "uas"
      "usb_storage"
      "sd_mod"
    ];
  };

  networking = {
    hostName = "regz";
    hostId = "ffdce650";
  };

  services = {
    openssh.enable = true;
    zfs = {
      trim.enable = true;
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
  };

  fileSystems = {
    "/boot" = {
      device = "/dev/disk/by-label/boot";
      fsType = "vfat";
    };
    "/" = {
      device = "zpool/root";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };
    "/nix" = {
      device = "zpool/nix";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };
    "/home" = {
      device = "zpool/home";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };
    "/var" = {
      device = "zpool/var";
      fsType = "zfs";
      options = [ "zfsutil" ];
    };
  };
}
