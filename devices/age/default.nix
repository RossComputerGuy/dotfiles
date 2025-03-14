{ config, pkgs, lib, inputs, ... }:
{
  # Bootloader
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.enable = true;

  fileSystems."/" =
    { device = "/dev/disk/by-partlabel/ROOT";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-partlabel/EFI";
      fsType = "vfat";
    };

  services.ttyd = {
    enable = true;
    writeable = true;
  };
}
