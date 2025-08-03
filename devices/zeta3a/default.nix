{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    ../../system/linux/desktop.nix
  ];

  environment.systemPackages = with pkgs; [ vlc ];

  programs.obs-studio = {
    enable = true;
    package = pkgs.obs-studio.override {
      cudaSupport = true;
    };
    plugins = with pkgs.obs-studio-plugins; [ wlrobs obs-webkitgtk ];
  };

  # allow matthewcroughan to do remote builds
  nix = {
    settings.trusted-users = [ "nix-ssh" ];
    sshServe = {
      protocol = "ssh-ng";
      enable = true;
      write = true;
      keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOq9gQxVP6k8TNYgkBR+oasyEIooP3QTPmWSkyvywic6 root@t480"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJRGo4DFyjy4qaQK+UyTECRURVVNs2ZqyVRfGAqc6t0a matthew@t480"
      ];
    };
  };

  # Bootloader
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = true;
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.devNodes = "/dev/";

  boot.kernelPatches = [
    {
      name = "perf";
      patch = null;
      extraStructuredConfig = with lib.kernel; {
        ARM64_64K_PAGES = yes;
        HZ_100 = yes;
      };
    }
  ];

  boot.extraModulePackages = with config.boot.kernelPackages; [ tt-kmd ];

  boot.kernelModules = [ "tenstorrent" ];

  boot.binfmt.emulatedSystems = [
    "x86_64-linux"
    "i686-linux"
    "i386-linux"
  ];

  # Initrd
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "uas" "usb_storage" "sd_mod" "nvidia" ];

  # Networking
  networking.hostName = "zeta3a";
  networking.hostId = "f174c9ca";

  services.openssh.enable = true;

  # Graphics
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia.open = true;

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

  i18n.inputMethod.enable = lib.mkForce false;

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
