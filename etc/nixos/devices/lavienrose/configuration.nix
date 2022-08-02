{ config, lib, pkgs, modulesPath, ... }:

{
  # Bootloader

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Initrd
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];

  # Kernel
  boot.kernelModules = [ "kvm-amd" ];
  boot.kernelModules = [ "overlay" "nct6775" ];
  boot.extraModprobeConfig = ''
    options kvm_intel nested=1
  '';

  # Hardware
  hardware.bluetooth.enable = true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  virtualisation.docker.enableNvidia = true;

  environment.etc."sysconfig/lm_sensors".text = ''
    HWMON_MODULES="nct6775"
  '';

  # Networking
  networking.hostName = "lavienrose";
  networking.interfaces.enp34s0.useDHCP = true;

  # Graphics
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable;

  # Services
  services.irqbalance.enable = true;
  services.ananicy.enable = true;
}
