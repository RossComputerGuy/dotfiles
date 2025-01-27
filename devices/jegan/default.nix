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
      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/55E7-0E35";
        fsType = "vfat";
      };

      fileSystems."/" = {
        device = "/dev/disk/by-uuid/997fc0c7-2860-4924-a732-04493c579f20";
        fsType = "ext4";
      };

      boot.loader = {
        systemd-boot.enable = true;
        generic-extlinux-compatible.enable = false;
      };

      boot.initrd.availableKernelModules = [
        "nvme" "pcie_starfive" "phy_jh7110_pcie"
      ];
    })
  ];
}
