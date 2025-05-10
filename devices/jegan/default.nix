{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    #../../system/linux/desktop.nix
    inputs.nixos-hardware.nixosModules.starfive-visionfive-2
  ];

  config = lib.mkMerge [
    {
      documentation = {
        enable = false;
        man.enable = false;
        info.enable = false;
        doc.enable = false;
        dev.enable = false;
        nixos.enable = false;
      };

      hardware.deviceTree.name = "starfive/jh7110-starfive-visionfive-2-v1.3b.dtb";

      networking = {
        hostName = "jegan";
        networkmanager.plugins = lib.mkForce [];
      };

      services.udisks2.enable = lib.mkForce false;

      virtualisation = {
        docker.enable = lib.mkForce false;
        libvirtd.enable = lib.mkForce false;
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
