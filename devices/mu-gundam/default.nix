{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    inputs.disko.nixosModules.default
  ];

  boot.kernelPackages = lib.mkDefault (pkgs.linuxPackagesFor (
    pkgs.buildLinux rec {
      version = "6.6.18";
      modDirVersion = version;
      src = pkgs.fetchFromGitHub {
        owner = "DC-DeepComputing";
        repo = "fml13v03_linux";
        rev = "7842fe7eb2ccc33fc7002dd2a04e575831b921c3";
        hash = "sha256-/ysRPYqIW1CJ0Itp1cVkQk5d3mzqqXYI4rleCIDY6yE=";
      };
      defconfig = "fml13v03_defconfig";
      kernelPatches = [
        {
          name = "fix-eswin-ai-dsp";
          patch = ./linux-fix-eswin-ai-dsp.patch;
        }
        {
          name = "fix-eswin-media-ext";
          patch = ./linux-fix-eswin-media-ext.patch;
        }
        {
          name = "fix-ap12275";
          patch = ./linux-fix-ap12275.patch;
        }
        {
          name = "fix-eswin-mem";
          patch = ./linux-fix-eswin-mem.patch;
        }
        {
          name = "fix-eswin-headers";
          patch = ./linux-fix-eswin-headers.patch;
        }
        {
          name = "fix-eswin-dev-buff";
          patch = ./linux-fix-eswin-dev-buff.patch;
        }
        {
          name = "fix-eswin-codec-conflict";
          patch = ./linux-fix-eswin-codec-conflict.patch;
        }
        {
          name = "fix-eswin-sysfs";
          patch = ./linux-fix-eswin-sysfs.patch;
        }
      ];
      structuredExtraConfig =
        (import "${pkgs.path}/pkgs/os-specific/linux/kernel/common-config.nix" {
          inherit (pkgs) stdenv;
          inherit lib version;
          rustAvailable = lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.rustc-unwrapped;
          features = {
            efiBootStub = true;
            netfilterRPFilter = true;
            ia32Emulation = true;
          };
        })
        // (with lib.kernel; {
          DWC_MIPI_TC_DPHY_GEN3 = no;
          DEBUG_INFO_BTF = no;
        });
      enableCommonConfig = false;
    }
  ));

  system.build = {
    uboot = pkgs.buildUBoot {
      defconfig = "deepcomputing-fml13v03_defconfig";
      extraMeta.platforms = [ "riscv64-linux" ];
      filesToInstall = [
        "u-boot.bin"
        "u-boot.dtb"
      ];
      version = "2024.01";
      src = pkgs.fetchFromGitHub {
        owner = "DC-DeepComputing";
        repo = "fml13v03_u-boot";
        rev = "d68387b6204343f98d82164fb62613029dfc8528";
        hash = "sha256-cgVjGXityxsnqs/onLJ0E6tlLI4YH1LALUA/rM+LPUg=";
      };
      NIX_CFLAGS_COMPILE = "-Wno-implicit-function-declaration -Wno-incompatible-pointer-types -Wno-int-conversion";
    };
    opensbi =
      (pkgs.opensbi.overrideAttrs (
        f: p: {
          src = pkgs.fetchFromGitHub {
            owner = "DC-DeepComputing";
            repo = "fml13v03_opensbi";
            rev = "37fc216159a439a4810900a109f45aa4b54e4b3a";
            hash = "sha256-RvZapBfQAokxVMNT2VU0tJqeI4LxMQTs1n+z74mR8XU=";
          };

          makeFlags = p.makeFlags ++ [
            "CHIPLET=BR2_CHIPLET_2"
            "CHIPLET_DIE_AVAILABLE=BR2_CHIPLET_1_DIE1_AVAILABLE"
            "PLATFORM_CLUSTER_X_CORE=BR2_CLUSTER_4_CORE"
            "MEM_MODE=BR2_MEMMODE_FLAT"
          ];
        }
      )).override
        {
          withPlatform = "eswin/eic770x";
          withPayload = "${config.system.build.uboot}/u-boot.bin";
          withFDT = "${config.system.build.uboot}/u-boot.dtb";
        };
    secboot = pkgs.pkgsCross.riscv64-embedded.stdenv.mkDerivation (finalAttrs: {
      pname = "secboot";
      version = "0-unstable-2025-07-27";

      src = pkgs.fetchFromGitHub {
        owner = "DC-DeepComputing";
        repo = "fml13v03_secboot_fw";
        rev = "16edc598e626aae096e3dfe16f4781f6731a8dec";
        hash = "sha256-Fl1MwADKfM453Em+K6QBMfaHtxWK7Ehr/86+JmcNVY0=";
      };

      NIX_CFLAGS_COMPILE = "-no-pie";

      makeFlags = [
        "CROSS_COMPILE=${pkgs.pkgsCross.riscv64-embedded.stdenv.cc.targetPrefix}"
        "BIN_DIR_FOR_DOWNLOAD=${placeholder "out"}"
      ];

      preBuild = ''
        mkdir -p $out
      '';

      dontInstall = true;
    });
    firmware-tools =
      let
        pkgsx86_64 =
          if pkgs.stdenv.hostPlatform.system == "x86_64-linux" then
            pkgs.buildPlatform
          else
            pkgs.pkgsCross.gnu64;
      in
      pkgsx86_64.stdenv.mkDerivation (finalAttrs: {
        name = "firmware-eswin-fml13v03";

        src = pkgsx86_64.fetchFromGitHub {
          owner = "DC-DeepComputing";
          repo = "fml13v03";
          rev = "e93f8903f9eb9fc34e9130881f56d6f2a08205c2";
          hash = "sha256-bMAYGA9/Ml5a0Eynmvcl+JGMZRf+1Uka43qCjxswO/s=";
        };

        sourceRoot = "${finalAttrs.src.name}/source";

        nativeBuildInputs = [
          pkgs.autoPatchelfHook
        ];

        buildInputs = [
          pkgsx86_64.stdenv.cc.cc
        ];

        installPhase = ''
          mkdir -p $out/bin
          mv firmware-eswin/nsign $out/bin/nsign

          patchelf --set-interpreter ${pkgsx86_64.stdenv.cc.libc}/lib/ld-linux-x86-64.so.2 $out/bin/nsign

          mkdir -p $out/lib
          mv firmware-eswin $out/lib/$name
        '';
      });
  };

  # Bootloader
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.systemd-boot.enable = true;
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.devNodes = "/dev/";

  networking = {
    hostId = "2da25905";
    hostName = "mu-gundam";
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

  services = {
    fwupd.enable = lib.mkForce false;
    udisks2.enable = lib.mkForce false;
  };

  disko = {
    imageBuilder = {
      enableBinfmt = true;
      kernelPackages = lib.mkForce pkgs.buildPackages.linuxPackages;
      pkgs = pkgs.buildPackages;
    };
    memSize = lib.mkDefault 4096;
    devices = {
      disk.nvme = {
        device = "/dev/nvme0n1";
        type = "disk";
        imageSize = "12G";
        content = {
          type = "gpt";
          partitions = {
            esp = {
              type = "EF00";
              size = "1G";
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
        preCreateHook = ''
          ls -ahl
        '';
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

  virtualisation = {
    docker.enable = lib.mkForce false;
    libvirtd.enable = lib.mkForce false;
  };
}
