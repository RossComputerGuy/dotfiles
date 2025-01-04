{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    inputs.nixos-hardware.nixosModules.starfive-visionfive-2
  ];

  config = lib.mkMerge [
    {
      networking.hostName = "jegan";
    }
    (lib.mkIf (pkgs.stdenv.hostPlatform.system == pkgs.stdenv.buildPlatform.system) {
      fileSystems."/" = {
        device = "/dev/nvme0n1p2";
        fsType = "ext4";
      };
    })
  ];
}
