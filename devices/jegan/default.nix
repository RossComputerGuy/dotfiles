{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.starfive-visionfive-2
  ];

  boot.loader.systemd-boot.enable = true;

  networking.hostName = "jegan";

  fileSystems."/" =
    { device = "/dev/nvme0n1p2";
      fsType = "ext4";
    };
}
