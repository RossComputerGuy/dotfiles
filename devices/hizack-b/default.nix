{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    ../../system/linux/desktop.nix
    inputs.nixos-apple-silicon.nixosModules.default
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  boot.kernelParams = [ "apple_dcp.unstable_edid=1" "apple_dcp.show_notch=1" ];
  /*boot.kernelPackages = lib.mkForce (pkgs.linuxPackagesFor ((pkgs.linuxKernel.manualConfig (rec {
    version = "6.12.1-asahi";
    modDirVersion = version;
    extraMeta.branch = "6.12";

    src = pkgs.fetchFromGitHub {
      owner = "AsahiLinux";
      repo = "linux";
      rev = "asahi-6.12.1-1";
      hash = "sha256-gXC+2I9N7Vg4aAfZYpFhCjZJWHrZpfSepuNDzIFHTuk=";
    };

    inherit (pkgs.linux-asahi.kernel) configfile kernelPatches config;
  })).overrideAttrs (f: p: {
    inherit (pkgs.linux-asahi.kernel) nativeBuildInputs buildInputs RUST_LIB_SRC;
  })));*/

  boot.binfmt.emulatedSystems = [
    "x86_64-linux"
    "i686-linux"
    "i386-linux"
  ];

  environment = {
    etc."containers/policy.json".text = builtins.toJSON {
      default = [{ type = "insecureAcceptAnything"; }];
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
      plugins = lib.mkForce (with pkgs; [
        networkmanager-fortisslvpn
        networkmanager-iodine
        networkmanager-l2tp
        networkmanager-openvpn
        networkmanager-vpnc
        networkmanager-sstp
      ]);
    };
  };

  hardware.asahi = {
    extractPeripheralFirmware = true;
    peripheralFirmwareDirectory = ./firmware;
    useExperimentalGPUDriver = true;
    setupAsahiSound = true;
    experimentalGPUInstallMode = "overlay";
  };

  boot.extraModprobeConfig = ''
    options hid_apple iso_layout=0
  '';

  fileSystems."/" = {
    device = "/dev/nvme0n1p5";
    fsType = "ext4";
  };

  home-manager.users.ross.wayland.windowManager.hyprland.package = lib.mkForce inputs.self.packages."${pkgs.stdenv.targetPlatform.system}".hyprland-legacy-renderer;
  home-manager.users.ross.xdg.configFile."kanshi/config".source = ./config/kanshi/config;
}
