{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    ../../system/linux/desktop.nix
    inputs.disko.nixosModules.default
    "${inputs.nixos-hardware}/rockchip/default.nix"
  ];

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = true;
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.devNodes = "/dev/";

  boot.initrd.kernelModules = [ "mmc_block" ];

  services.xserver.enable = true;

  networking = {
    hostName = "jeda";
    hostId = "d0976c4e";
  };

  hardware.rockchip.enable = true;

  disko = {
    memSize = lib.mkDefault 4096;
    devices = {
      disk.mmc = {
        type = "disk";
        imageSize = "6G";
        content = {
          type = "gpt";
          partitions = {
            efi-system = {
              size = "8M";
            };
            esp = {
              type = "EF00";
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
            options = {
              encryption = "aes-256-gcm";
              keyformat = "passphrase";
              keylocation = "file://${./tmpkey}";#"prompt";
            };
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
