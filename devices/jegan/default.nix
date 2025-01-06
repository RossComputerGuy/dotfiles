{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    #../../system/linux/desktop.nix
    inputs.nixos-hardware.nixosModules.starfive-visionfive-2
  ];

  config = lib.mkMerge [
    {
      networking = {
        hostName = "jegan";
        networkmanager.plugins = lib.mkForce (with pkgs; [
          networkmanager-fortisslvpn
          networkmanager-iodine
          networkmanager-l2tp
          networkmanager-openvpn
          networkmanager-vpnc
          networkmanager-sstp
        ]);
      };
    }
    (lib.mkIf (pkgs.stdenv.hostPlatform.system == pkgs.stdenv.buildPlatform.system) {
      fileSystems."/" = {
        device = "/dev/nvme0n1p2";
        fsType = "ext4";
      };

      boot.loader = {
        systemd-boot.enable = true;
        generic-extlinux-compatible.enable = false;
      };
    })
  ];
}
