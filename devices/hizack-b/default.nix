{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    ../../system/linux/desktop.nix
    inputs.nixos-apple-silicon.nixosModules.default
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  boot.kernelParams = [
    "apple_dcp.unstable_edid=1"
    "apple_dcp.show_notch=1"
    "appledrm.show_notch=1"
  ];

  boot.binfmt.emulatedSystems = [
    "x86_64-linux"
    "i686-linux"
    "i386-linux"
  ];

  environment = {
    etc."containers/policy.json".text = builtins.toJSON {
      default = [ { type = "insecureAcceptAnything"; } ];
    };
    systemPackages = with pkgs; [
      openscad
      mpv
      vlc
    ];
  };

  hardware.bluetooth.enable = true;
  networking = {
    hostName = "hizack-b";
    wireless = {
      enable = false;
      iwd.enable = true;
    };
    networkmanager = {
      wifi.backend = "iwd";
      plugins = lib.mkForce (
        with pkgs;
        [
          networkmanager-fortisslvpn
          networkmanager-iodine
          networkmanager-l2tp
          networkmanager-openvpn
          networkmanager-vpnc
          networkmanager-sstp
        ]
      );
    };
  };

  hardware.asahi = {
    extractPeripheralFirmware = true;
    peripheralFirmwareDirectory = ./firmware;
    setupAsahiSound = true;
  };

  boot.extraModprobeConfig = ''
    options hid_apple iso_layout=0
  '';

  fileSystems."/" = {
    device = "/dev/nvme0n1p5";
    fsType = "ext4";
  };
}
