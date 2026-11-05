{ config, pkgs, lib, inputs, ... }:
let
  ap6275p = pkgs.callPackage ./ap6275p.nix {};
in
{
  imports = [
    ../../system/linux/desktop.nix
    inputs.disko.nixosModules.default
    inputs.nixos-hardware-fydetab.nixosModules.fydetab-duo
  ];

  boot.loader = {
    generic-extlinux-compatible.enable = true;
    grub.enable = false;
  };

  boot.supportedFilesystems = [ "zfs" ];
  # Only scan partitions. A reflash leaves old pool labels at the end of the raw disk.
  boot.zfs.devNodes = "/dev/disk/by-partlabel";

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
  hardware.bluetooth.enable = true;

  boot.kernelParams = [
    # Reset a hung tablet so it can be put in maskrom from u-boot without the button.
    "panic=10"
    # boot.plymouth adds "splash" by itself, so only "quiet" belongs here.
    "quiet"
    "udev.log_level=3"
    "rd.udev.log_level=3"
    "systemd.show_status=auto"
    "rd.systemd.show_status=auto"
  ];

  boot.plymouth.enable = true;

  # Touch keyboard for the ZFS passphrase. unl0kr refuses to start while Plymouth runs, so
  # Plymouth gives up the display for the prompt and takes it back after. The plymouth
  # module puts its client at /bin/plymouth in the initrd.
  boot.initrd.unl0kr = {
    enable = true;
    settings.general.backend = "drm";
  };
  boot.initrd.systemd.services.unl0kr-agent = {
    unitConfig.ConditionPathExists = lib.mkForce "";
    serviceConfig = {
      ExecStartPre = "-/bin/plymouth deactivate";
      ExecStopPost = "-/bin/plymouth reactivate";
    };
  };
  boot.initrd.systemd.paths.unl0kr-agent.unitConfig.ConditionPathExists = lib.mkForce "";
  # The unl0kr module adds i2c-hid-acpi, and this kernel has no ACPI.
  nixpkgs.overlays = [
    (final: prev: {
      makeModulesClosure = args: prev.makeModulesClosure (args // { allowMissing = true; });
    })
  ];
  # The vendor drivers log many warnings that would print over the splash.
  boot.consoleLogLevel = 3;
  boot.initrd.systemd.settings.Manager.RuntimeWatchdogSec = "20s";
  systemd.settings.Manager.RuntimeWatchdogSec = "20s";

  home-manager.users.ross.ross.cosmic.panelExtraApplets = [ "com.system76.CosmicAppletOsk" ];
  hardware.rockchip.diskoImageName = "mmc.raw";

  disko = {
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
        imageSize = "24G";
        content = {
          type = "gpt";
          partitions = {
            # U-Boot finds its charging and loader bitmaps by this exact GPT name.
            resource = {
              label = "resource";
              alignment = 1;
              start = "24580";
              end = "65535";
            };
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
          encryption = "aes-256-gcm";
          keyformat = "passphrase";
          keylocation = "file:///tmp/secret.key";
        };
        # The image is built with a temporary passphrase. Replace it on the tablet with
        # `zfs change-key zpool` after the first boot.
        preCreateHook = "echo -n changeme-jeda > /tmp/secret.key";
        postCreateHook = "zfs set keylocation=prompt zpool";
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

  # 8 GiB is not enough for a browser. Same setup as hizack-b.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
  };

  # The same as hizack-b. A tablet is away often, so it reaches argama over the
  # tailnet and reads as down on the dashboards while it sleeps.
  ross.backup.enable = true;
  ross.monitoring.enable = true;
  ross.remoteBuild.enable = true;

  # No sshd here, so no host certificate. Only the nixremote client key.
  ross.sshCa.clientCerts = [ "nixremote" ];
  ross.remoteBuild.sshKey = "/var/lib/ssh-client-cert/nixremote";

  services.zfs = {
    # The disko image is smaller than the eMMC.
    expandOnBoot = [ "zpool" ];
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
