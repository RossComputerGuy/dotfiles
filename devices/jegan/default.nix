{ config, lib, pkgs, ... }:
with lib;
{
  boot.loader.systemd-boot.enable = true;

  networking.hostName = "jegan";

  fileSystems."/" =
    { device = "/dev/nvme0n1p2";
      fsType = "ext4";
    };
}
