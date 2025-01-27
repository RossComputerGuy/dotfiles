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
        "dw_mmc-starfive"
        "motorcomm"
        "dwmac-starfive"
		    "cdns3-starfive"
		    "jh7110-trng"
		    "phy-jh7110-usb"
        "clk-starfive-jh7110-aon"
		    "clk-starfive-jh7110-stg"
		    "clk-starfive-jh7110-vout"
		    "clk-starfive-jh7110-isp"
		    "clk-starfive-jh7100-audio"
		    "phy-jh7110-pcie"
		    "pcie-starfive"
		    "nvme"
      ];
    })
  ];
}
