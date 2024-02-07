{ config, lib, pkgs, ... }:
with lib;
{
  networking.hostName = "jegan";

  fileSystems."/" =
    { device = "/dev/nvme0n1p2";
      fsType = "ext4";
    };
}
