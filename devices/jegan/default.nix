{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.starfive-visionfive-2
  ];

  networking.hostName = "jegan";

  fileSystems."/" =
    { device = "/dev/nvme0n1p2";
      fsType = "ext4";
    };
}
