{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    ../../system/linux/desktop.nix
    inputs.disko.nixosModules.default
    "${inputs.nixos-hardware}/rockchip/default.nix"
  ];

  hardware.rockchip.diskoImageName = "mmc.raw";

  hardware.rockchip.platformFirmware = pkgs.buildUBoot {
    defconfig = "rk3588s_fydetab_duo_defconfig";
    extraMeta.platforms = [ "aarch64-linux" ];
    BL31 = "${pkgs.armTrustedFirmwareRK3588}/bl31.elf";
    ROCKCHIP_TPL = pkgs.rkbin.TPL_RK3588;
    CROSS_COMPILE_ARM64 = "${pkgs.stdenv.cc}/bin/";
    INI_LOADER = pkgs.fetchurl {
      url = "https://github.com/rockchip-linux/rkbin/raw/${pkgs.rkbin.src.rev}/RKBOOT/RK3588MINIALL.ini";
      hash = "sha256-87Vt6nXVt+jRrRatOlwGJXYqSj9nJz1LUfQnviIVb7I=";
    };
    version = "5.10.0";
    filesToInstall = [
      "idbloader.img"
      "u-boot.itb"
      "rk3588_spl_loader_v1.18.113.bin"
      "tools/resource_tool"
    ];
    NIX_CFLAGS_COMPILE = "-Wno-error=enum-int-mismatch -Wno-error=maybe-uninitialized";
    extraMakeFlags = [
      "CROSS_COMPILE_ARM64="
    ];
    extraPatches = lib.attrValues (lib.mapAttrs (name: hash: pkgs.fetchpatch {
      url = "https://github.com/openFyde/overlay-fydetab_duo-openfyde/raw/fd84c5302908dea6a819c2dcd025a2bf93b5d4e8/sys-boot/rk-uboot/files/rk8/${name}";
      inherit hash;
    }) {
      "001-add-avdd-avee-in-rockchip_panel.patch" = "sha256-qmBdmSejcDn4ulvOTLjfBsNh6nl12sbobtX4mhTMMKY=";
      "002-add-fydetab-support.patch" = "sha256-QlnhdkoOQcGxRiIOx1jNqDLb/abB/+l+hAQ8vKCpwOw=";
      "003-match-display-config-with-kernel.patch" = "sha256-hmICiAgYjjBryJIuNXOffiYTssKSaV1cDeSgRTdq51k=";
      "004-enable-sdcard-for-fydetab.patch" = "sha256-xrZ1kuije6X+huvarDIGFhMy2Puq0XvlKa1ZfgGcwlQ=";
      "005-display-logo-on-loader-mode.patch" = "sha256-NMQHJMl8s1NUrDSnUX8gAmSNaurBU+m0xKd4TtEPmz4=";
      "006-update-deconfig.patch" = "sha256-ZukJEZjEFaN6F4+3VnHfkfdaOTQmkw3fdClk8OeOYRw=";
      "007-add-deinit-after-show-bmp-add-ums-mode.patch" = "sha256-4pHV+qiXMNHcIlC1ciFQsejVZvdnEhfs7QBbge9kHoM=";
      "008-add-charging-mode.patch" = "sha256-AToALdx5mwyQ875ZnrpqbuUE9oGonH76RaUq6757U1E=";
      "009-set-lowpower-to-3.patch" = "sha256-CYYmY8vQcOIiA3QPvZt+AgI/BbkykoKGqLECim7kAyw=";
      "010-fix-compiling-issue.patch" = "sha256-hmiFFe0JuxXMPgeQFWI8qZop+VPmldxgs0Wowchswbs=";
      "011-fix-battery-temp.patch" = "sha256-MXe5FGzGETZ3wpW7ur5rBLysdNlDMwiq7/LNxdDpA0E=";
      "012-fix-make.patch" = "sha256-/8ZfhB04R4zIddOXJEx8GcnYoljYsGolbt/oQYsm/Xk=";
      "013-change-exit-charge-level.patch" = "sha256-84zy5yzoHyAutVmbCvvB5t4uJFQGsMt3jTUgVs5SIog=";
      "014-fix-spl-sdcard-issue.patch" = "sha256-jIHybAm9XKDbWF3xG4E9K8x2j5nfpHOp6/2gWDlQ6aU=";
    }) ++ [
      ./remove-sig-req.patch
    ];
    src = pkgs.fetchFromGitHub {
      owner = "rockchip-linux";
      repo = "u-boot";
      rev = "63c55618fbdc36333db4cf12f7d6a28f0a178017";
      hash = "sha256-OZmR6BLwCMK6lq9qmetIdrjSJJWcx7Po1OE9dBWL+Ew=";
    };
    extraConfig = ''
      CONFIG_FIT_SIGNATURE=n
      CONFIG_TPL_BUILD=y
      CONFIG_SPL_FIT_SIGNATURE=n
      CONFIG_SPL_FIT_ROLLBACK_PROTECT=n
      CONFIG_EFI_LOADER=y
      CONFIG_CMD_BOOTEFI=y
      CONFIG_CMD_BOOTEFI_HELLO_COMPILE=n
      CONFIG_GENERATE_SMBIOS_TABLE=n
      CONFIG_EFI_LOADER_BOUNCE_BUFFER=n
      CONFIG_FIT_VERBOSE=y
      CONFIG_CONSOLE_DISABLE_CLI=n
      CONFIG_CMD_FDT=y
      CONFIG_DEFAULT_FDT_FILE="rk3588s-fydetab-duo.dtb"
    '';
    preBuild = ''
      patchShebangs arch/arm/mach-rockchip/make_fit_atf.sh
      patchShebangs arch/arm/mach-rockchip/decode_bl31.py

      cp -r ${pkgs.rkbin.src} rkbin
      chmod -R u+rw rkbin

      export RKBIN_TOOLS=$(readlink -e rkbin/tools)
      ln -s ${pkgs.rkbin}/bin bin

      cp ${pkgs.rkbin.src}/tools/boot_merger tools/
      cp ${pkgs.rkbin.src}/tools/mkimage tools/
    '';
    postBuild = ''
      sh ./make.sh --spl
      sh ./make.sh --idblock
      sh ./make.sh itb
      mv idblock.bin idbloader.img
    '';
    nativeBuildInputs = [
      pkgs.pkg-config
      pkgs.ncurses
      pkgs.openssl
      pkgs.which
      pkgs.bc
      pkgs.python3
      pkgs.dtc
    ];
  };

  system.build.ubootResource = pkgs.runCommand "u-boot-resource.img" {
    srcs = lib.attrValues (lib.mapAttrs (name: hash: pkgs.fetchurl {
      url = "https://github.com/openFyde/overlay-fydetab_duo-openfyde/raw/refs/heads/main/sys-boot/rk-uboot-resource/files/${name}";
      inherit hash;
    }) {
      "fydetab_batt1.bmp" = "sha256-I4JqZLLdSOxfC6TvOwdRrhvdrPXVNpTHJyae+Sq73wE=";
      "fydetab_batt2.bmp" = "sha256-psRUFJaove7dDv57y7YGM8f57q4kLgKdXaTtAHMAD6M=";
      "fydetab_batt_fail.bmp" = "sha256-ZvKjc6ycMHkXy301CdDfTixp+cpccDU5eJlkoAtdu34=";
      "fydetab_recovery.bmp" = "sha256-9M2ms4GRVQogAD+OGZRTJMqGjM4AhhKhhLCopsiqu2s=";
      "fydetab_usb.bmp" = "sha256-jvegjta7Sg9eWF8v6NCXG6o/Bv8T6rk0naq92IoFYcw=";
    });
  } ''
    for src in $srcs; do
      name=$(basename $src)
      name=''${name#*-*}
      echo "Copying $src to $name"
      cp -r --no-preserve=ownership,mode $src $name
    done
    export PATH=${config.hardware.rockchip.platformFirmware}:$PATH
    resource_tool *.bmp
    mv resource.img $out
  '';

  boot.initrd.includeDefaultModules = false;

  boot.kernelParams = [
    "console=ttyFIQ0"
    "console=tty1"
    "console=both"
    "earlycon=uart8250,mmio32,0xfeb50000"
  ];

  boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.linuxManualConfig rec {
    version = "6.1.75";
    modDirVersion = version;
    src = pkgs.fetchFromGitHub {
      owner = "Linux-for-Fydetab-Duo";
      repo = "linux-rockchip";
      rev = "14294048d2a0deb7f38c890329aded87038d3299";
      hash = "sha256-POEctS1MzPJv15qiOUL+NoMFvDjgoo1Ki4JCSAZ4lwM=";
    };
    configfile = ./config;
    config = import ./config.nix;
    features.netfilterRPFilter = true;
    kernelPatches = [
      {
        name = "rk3588s-mali.patch";
        patch = ./rk3588s-mali.patch;
        extraConfig = {};
      }
    ];
  });

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
