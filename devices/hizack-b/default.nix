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
    # boot.plymouth adds "splash" by itself, so only "quiet" belongs here.
    "quiet"
  ];

  boot.plymouth.enable = true;

  # Firefox already had a profile here before Home Manager took over
  # profiles.ini, so name it. This machine keeps it under ~/.mozilla, which is
  # the ross.firefoxConfigPath default, unlike zeta3a.
  ross.firefoxProfilePath = "1cf0ubjk.default-1710463219262";

  boot.binfmt.emulatedSystems = [
    "x86_64-linux"
    "i686-linux"
    "i386-linux"
  ];

  # 16 GB is this machine's bottleneck; compressed RAM swap stretches usable
  # memory cheaply (zstd is ~free on the M1 Pro) and keeps the binary cache,
  # unlike CPU tuning. systemd-oomd is already on by default as a backstop.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 100;
  };

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

  # Backup
  # A laptop is away from home often, so it reaches argama over the tailnet.
  # The split horizon in argama's dns.nix answers with the right address.
  ross.backup.enable = true;

  # Appear on argama's dashboards. A laptop is away often, so expect this one to
  # read as down for long stretches. That is the truth and not a fault.
  ross.monitoring.enable = true;

  # Send builds to argama, over the tailnet when away from home. A laptop on
  # battery has every reason to hand a kernel build to a machine on mains.
  ross.remoteBuild.enable = true;

  # The key that reaches the nixremote account on argama. The unit makes the
  # key here on its first run and renews only the certificate after that, so
  # nothing secret travels and argama needs no pasted key. See
  # modules/ssh-ca.nix.
  #
  # No host certificate here. This machine runs no sshd, so nothing connects to
  # it and it has nothing to prove. Leave ross.sshCa.hostCert off, and leave
  # ssh-host-signer out of this machine's OpenBao policy.
  ross.sshCa.clientCerts = [ "nixremote" ];
  ross.remoteBuild.sshKey = "/var/lib/ssh-client-cert/nixremote";

  hardware.asahi.enable = true;
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
