{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./auth.nix
    ./backup.nix
    ./dns.nix
    ./documents.nix
    ./git.nix
    ./media.nix
    ./monitoring.nix
    ./radicle.nix
    ./secrets.nix
    ./web.nix
    ./yubikey.nix
  ];

  # argama is headless. system/linux/default.nix sets the desktop profile for
  # every Linux machine, so turn it back down to standard here.
  ross.profile = "standard";

  # Bootloader
  boot.loader.efi.canTouchEfiVariables = true;

  # The same secure boot setup as zeta3a. lanzaboote makes the keys and enrolls
  # them, and they stay in the pki bundle on disk. argama rebuilds without an
  # operator, so a signing key that is somewhere else would stop every rebuild.
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    autoGenerateKeys.enable = true;
    autoEnrollKeys.enable = true;
  };

  # sbctl reads the key state and the enrollment, the same as on zeta3a.
  environment.systemPackages = [ pkgs.sbctl ];

  # Same kernel as zeta3a. 64K pages and HZ_100 are the standard for the Ampere
  # machines here.
  boot.kernelPackages = pkgs.pkgsLLVM.linuxPackages_6_18;

  boot.kernelPatches = [
    {
      name = "perf";
      patch = null;
      structuredExtraConfig = with lib.kernel; {
        ARM64_64K_PAGES = yes;
        HZ_100 = yes;
      };
    }
    {
      name = "fixes";
      patch = null;
      structuredExtraConfig = with lib.kernel; {
        COMPAT_VDSO = no;
      };
    }
  ];

  # No console= parameter, the same as zeta3a on this same board. The firmware
  # gives the kernel an SPCR table which names the console and its speed, and
  # the kernel follows it. A hardcoded speed here would only be a second source
  # of truth that can disagree.
  #
  # earlycon reads that same table, so a headless machine prints from early in
  # the boot instead of from the point where the driver loads. There is no
  # "quiet" here for the same reason: nobody watches a screen on this machine.
  boot.kernelParams = [ "earlycon" ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "uas"
    "usb_storage"
    "sd_mod"
    "tpm_tis"
    "tpm_crb"
  ];

  # Storage
  boot.supportedFilesystems = [ "zfs" ];
  # devNodes stays at the nixpkgs default of /dev/disk/by-id, unlike zeta3a
  # which sets /dev/. It is the directory the import scans, and tank is made
  # from wwn- names. Scanning /dev/ would bind the pool to sdb and sdc instead,
  # and those letters move as soon as a disk is pulled or a cable changes.
  # hostId is pinned below, so a forced import of the root pool is safe. It
  # prevents a manual import after an unclean shutdown.
  boot.zfs.forceImportRoot = true;

  # The TPM releases the pool keys, so stage 1 must not ask for a passphrase.
  # An empty list also generates no "zfs load-key" at all, so both pools have to
  # be sealed to the TPM before the first boot. The README does that from the
  # installer, before the reboot, for exactly this reason.
  boot.zfs.requestEncryptionCredentials = lib.mkForce [ ];

  boot.zfs.tzpfms = {
    enable = true;
    backends = [ "TPM2" ];
    datasets = [
      "zpool"
      "tank"
    ];
  };

  services.zfs = {
    trim.enable = true;
    autoScrub = {
      enable = true;
      pools = [
        "zpool"
        "tank"
      ];
    };
    autoSnapshot = {
      enable = true;
      frequent = 8;
      monthly = 1;
    };
  };

  fileSystems."/" = {
    device = "zpool/root";
    fsType = "zfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  fileSystems."/nix" = {
    device = "zpool/nix";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "zpool/home";
    fsType = "zfs";
  };

  fileSystems."/var" = {
    device = "zpool/var";
    fsType = "zfs";
  };

  # The bulk data lives on tank, the spinning pool. zpool is a 931GB NVMe, which
  # holds neither a media library nor the backups of the fleet.
  #
  # The downloads and the library share this dataset. See media.nix for why they
  # must stay on one filesystem.
  fileSystems."/var/lib/media" = {
    device = "tank/media";
    fsType = "zfs";
  };

  # The backups that the other machines push. Their own dataset, so a snapshot
  # or a quota on them does not touch the media.
  fileSystems."/var/lib/restic" = {
    device = "tank/backups";
    fsType = "zfs";
  };

  # Networking
  networking.hostName = "argama";
  networking.hostId = "8564d4ac";

  services.openssh.enable = true;

  # No port is open here. Hydra answers at hydra.argama.nix and the binary cache
  # at cache.argama.nix, both through Caddy. See web.nix.

  # Builder
  # 64 cores. 8 concurrent builds with 8 cores each fills the machine and keeps
  # one slow build from holding all of it.
  nix.settings = {
    max-jobs = 8;
    cores = 8;
    # Hydra needs the derivations and the outputs to stay after a garbage
    # collection, or it must build every dependency again.
    keep-outputs = true;
    keep-derivations = true;
  };

  services.harmonia.cache = {
    enable = true;
    # The harmonia-key unit in secrets.nix copies this key out of OpenBao into
    # /run, because harmonia loads it with LoadCredential=. See that file.
    signKeyPaths = [ "/run/harmonia-key/cache.secret" ];
    settings.bind = "[::]:5000";
  };

  services.hydra = {
    enable = true;
    hydraURL = "https://hydra.argama.nix";
    listenHost = "localhost";
    port = 3000;
    notificationSender = "hydra@argama";
    # argama builds for itself. Add remote machines to this file when the other
    # architectures must build too.
    buildMachinesFiles = [ ];
    # Pull a path from cache.nixos.org if it is there. It is faster than a
    # local build of the same path.
    useSubstitutes = true;
  };

  services.irqbalance.enable = true;
}
