{ config, pkgs, lib, inputs, ... }:
let
  ap6275p = pkgs.callPackage ./ap6275p.nix {};
in
{
  imports = [
    ../../system/linux/desktop.nix
    inputs.disko.nixosModules.default
    inputs.nixos-hardware.nixosModules.fydetab-duo
  ];

  boot.loader = {
    generic-extlinux-compatible.enable = true;
    grub.enable = false;
  };

  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.devNodes = "/dev/";

  boot.initrd.kernelModules = [ "mmc_block" ];

  services.xserver.enable = true;

  networking = {
    hostName = "jeda";
    hostId = "d0976c4e";
    wireless = {
      enable = false;
      iwd.enable = true;
    };
    networkmanager.wifi.backend = "iwd";
  };

  hardware.sensor.iio.enable = true;

  disko = lib.mkForce {
    imageBuilder = {
      kernelPackages = pkgs.linuxPackages;
      extraPostVM = config.hardware.rockchip.diskoExtraPostVM + ''
        dd conv=notrunc,fsync if=${config.system.build.ubootResource} of=$out/mmc.raw bs=512 seek=24580
      '';
    };
    memSize = lib.mkDefault 4096;
    devices = {
      disk.mmc = {
        type = "disk";
        imageSize = "8G";
        content = {
          type = "gpt";
          partitions = {
            esp = {
              type = "EF00";
              start = "32M";
              # Firmware backoff
              size = "500M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0022" ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zpool";
             };
           };
          };
        };
      };
      zpool.zpool = {
        type = "zpool";
        rootFsOptions = {
          mountpoint = "none";
          compression = "zstd";
        };
        datasets = {
          root = {
            type = "zfs_fs";
            mountpoint = "/";
          };
          nix = {
            type = "zfs_fs";
            options.mountpoint = "/nix";
            mountpoint = "/nix";
          };
          home = {
            type = "zfs_fs";
            options.mountpoint = "/home";
            mountpoint = "/home";
          };
          var = {
            type = "zfs_fs";
            options.mountpoint = "/var";
            mountpoint = "/var";
          };
        };
      };
    };
  };

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
}
