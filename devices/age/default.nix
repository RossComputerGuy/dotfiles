{ config, pkgs, lib, inputs, ... }:
{
  # Bootloader
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    device = "/dev/disk/by-partlabel/EFI";
  };

  fileSystems."/" =
    { device = "/dev/disk/by-partlabel/ROOT";
      fsType = "ext4";
    };

  fileSystems."/boot/efi" =
    { device = "/dev/disk/by-partlabel/EFI";
      fsType = "vfat";
    };

  services = {
    ttyd = {
      enable = true;
      writeable = true;
    };
    fwupd.enable = lib.mkForce false;
    udisks2.enable = lib.mkForce false;
  };

  virtualisation = {
    docker.enable = lib.mkForce false;
    libvirtd.enable = lib.mkForce false;
  };
}
