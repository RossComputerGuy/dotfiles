{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  ftModels = import ../../users/ross/opencode-models.nix;
  # Each model listens on its own fixed port. llama-swap does offer a ${PORT}
  # macro, but it allocates that in lexicographic model-id order while it reads
  # the configuration, so adding an id that sorts early would move every port
  # after it.
  ftPort = name: 5010 + ftModels.${name}.index;

  mcpServers = import ../../users/ross/mcp-servers.nix { inherit pkgs lib; };
  globalMcp = lib.filterAttrs (_: s: s.scope == "global") mcpServers;
  # There is no mcpUiConfig any more. It described the MCP servers to
  # llama.cpp's own web interface, and FreeToken has no such interface. opencode
  # reaches these servers through its own configuration, so nothing is lost
  # except the browser page.
  mcpProxyConfig = pkgs.writeText "mcp-proxy.json" (
    builtins.toJSON {
      mcpServers = lib.mapAttrs (name: s: {
        command = builtins.head s.command;
        args = builtins.tail s.command;
        enabled = true;
        env = lib.optionalAttrs (name == "memory") {
          MEMORY_FILE_PATH = "/var/lib/mcp-proxy/memory.json";
        };
      }) globalMcp;
    }
  );
in
{
  imports = [
    ../../system/linux/desktop.nix
  ];

  environment.systemPackages = with pkgs; [
    vlc
    sbctl
    # ykchalresp answers the passphrase on the pool's sealed TPM object. Without
    # it on the machine, a rescue shell has no way to compute that answer and no
    # network to fetch the tool. See the README.
    yubikey-personalization
    nvtopPackages.nvidia
    dsview
  ];

  # FreeToken serves one model per process, so llama-swap sits in front and
  # starts the one a request asks for. With no groups block every model lands in
  # the implicit "(default)" group, where swap and exclusive are both true, so
  # exactly one model holds the 12GB card at any moment.
  services.llama-swap = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 5001;
    settings = {
      # A model load reads more than 100GB, so the probe has to outlast it.
      # llama-swap kills the process when this passes. The value is global: the
      # per-model field of the same name is only a copy of it and overrides
      # nothing.
      healthCheckTimeout = 1800;
      logLevel = "info";
      models = lib.mapAttrs (name: m: {
        # /healthz, and not /health. FreeToken answers /health with HTTP 200 in
        # every state, while it loads and after it dies, and llama-swap reads
        # only the status code. The patch in pkgs/freetoken adds /healthz, which
        # answers 503 until the engine serves.
        checkEndpoint = "/healthz";
        proxy = "http://127.0.0.1:${toString (ftPort name)}";
        ttl = 900;
        name = m.display;
        env = [
          # FreeToken reads no download path of its own. It calls
          # huggingface_hub, so that library's own variable decides where the
          # weights land.
          "HF_HOME=/var/cache/llama-swap/hf"
          # ft bench bw profiles live below this one.
          "XDG_CACHE_HOME=/var/cache/llama-swap"
          # The prebuilt kernels otherwise sit beside the package in the store,
          # which is read only. A kernel variant the cache misses is compiled
          # at run time and needs somewhere to write.
          "FREETOKEN_KERNEL_CACHE_DIR=/var/cache/llama-swap/kernels"
        ];
        cmd = lib.concatStringsSep " " (
          [
            "${lib.getExe' pkgs.freetoken "ft"} serve"
            "--model ${m.repo}"
            "--served-model-name ${name}"
            "--host 127.0.0.1"
            "--port ${toString (ftPort name)}"
            # offload keeps the experts in host RAM and streams the active ones
            # over PCIe. Never cpu or hybrid, which compute the misses on the
            # CPU: those kernels are AVX only, so this Neoverse-N1 falls back to
            # scalar code. auto can choose hybrid, so name offload here.
            "--moe-backend offload"
          ]
          ++ m.args
        );
      }) ftModels;
    };
  };

  systemd.services.mcp-proxy = {
    bindsTo = [ "llama-swap.service" ];
    after = [ "llama-swap.service" ];
    wantedBy = [ "llama-swap.service" ];
    serviceConfig = {
      DynamicUser = true;
      StateDirectory = "mcp-proxy";
      Restart = "on-failure";
      ExecStart = "${lib.getExe' pkgs.mcp-proxy "mcp-proxy"} --transport streamablehttp --host 127.0.0.1 --port 5003 --named-server-config ${mcpProxyConfig}";
    };
  };

  services.caddy = {
    enable = true;
    virtualHosts.":5002".extraConfig = ''
      bind 127.0.0.1
      @get method GET
      handle @get {
        respond 405
      }
      handle {
        reverse_proxy 127.0.0.1:5003
      }
    '';
  };

  # The old llama-cpp unit polled /health from an ExecStartPost script. That is
  # gone, because llama-swap runs its own probe against checkEndpoint above.
  systemd.services.llama-swap = {
    wantedBy = lib.mkForce [ ];
    unitConfig.StopWhenUnneeded = true;
  };

  systemd.sockets.llama-swap-proxy = {
    wantedBy = [ "sockets.target" ];
    socketConfig.ListenStream = "0.0.0.0:5000";
  };

  systemd.services.llama-swap-proxy = {
    requires = [ "llama-swap.service" ];
    after = [ "llama-swap.service" ];
    serviceConfig.ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd --exit-idle-time=300s 127.0.0.1:5001";
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 5000 ];

  programs.obs-studio = {
    enable = true;
    # OBS upstream gates the NVENC plugin to x86_64 only, so on aarch64 it never
    # builds and no NVENC encoders show up — even though the RTX 5070 + driver
    # provide libnvidia-encode here. Add aarch64 to the plugin's allowed arches.
    package = (pkgs.obs-studio.override { cudaSupport = true; }).overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace plugins/CMakeLists.txt \
          --replace-fail \
            'add_obs_plugin(obs-nvenc PLATFORMS WINDOWS LINUX ARCHITECTURES x64 x86_64)' \
            'add_obs_plugin(obs-nvenc PLATFORMS WINDOWS LINUX ARCHITECTURES x64 x86_64 aarch64)'
      '';
    });
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
    ];
  };

  # NVENC only exists in this package when CUDA is on. The derivation sets
  # WIVRN_USE_NVENC from cudaSupport, which is false by default. The OBS patch
  # above is not necessary here, because WiVRn puts no architecture gate on
  # NVENC and builds it on aarch64.
  services.wivrn = {
    package = pkgs.wivrn.override { cudaSupport = true; };
    config = {
      # system/linux/vr.nix turns config on and sets the application. Only the
      # encoder is machine specific.
      #
      # One entry for each stream, and not a list of fallbacks. WiVRn encodes
      # the left eye, the right eye and the alpha channel as three streams, and
      # each entry sets the encoder for one of them.
      json.encoder = [
        {
          encoder = "nvenc";
          codec = "h265";
        }
        {
          encoder = "nvenc";
          codec = "h265";
        }
        {
          encoder = "nvenc";
          codec = "h265";
        }
      ];
    };
  };

  # allow matthewcroughan to do remote builds
  nix = {
    settings.trusted-users = [ "nix-ssh" ];
    sshServe = {
      protocol = "ssh-ng";
      enable = true;
      write = true;
      keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOq9gQxVP6k8TNYgkBR+oasyEIooP3QTPmWSkyvywic6 root@t480"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJRGo4DFyjy4qaQK+UyTECRURVVNs2ZqyVRfGAqc6t0a matthew@t480"
      ];
    };
  };

  # Bootloader
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.devNodes = "/dev/";
  # Keep force-importing the root pool (pre-26.11 behaviour). hostId is pinned,
  # so this is safe here and avoids a manual import after an unclean shutdown.
  boot.zfs.forceImportRoot = true;

  boot.zfs.requestEncryptionCredentials = lib.mkForce [ ];

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
    autoGenerateKeys.enable = true;
    autoEnrollKeys.enable = true;
    # /boot is 863MB, and one generation costs about 177MB there: a 62MB kernel
    # and an initrd of 110 to 119MB. The initrd is not shared between
    # generations that run the same kernel, because it is built from the whole
    # initrd configuration and not from the kernel version alone. There were two
    # separate 6.18.42 initrds here.
    #
    # A switch writes the new generation before it removes the old ones, so the
    # partition has to hold limit + 1 of them. Three gives a peak near 708MB and
    # keeps about 150MB spare. Four would peak near 885MB, which does not fit,
    # and that is how this partition filled to 100% with nothing set.
    configurationLimit = 3;
  };

  boot.zfs.tzpfms = {
    enable = true;
    backends = [ "TPM2" ];
    datasets = [ "zpool" ];
  };

  services.udev.packages = [ pkgs.dsview ];

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="1209", GROUP="plugdev", MODE="0660"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="2a0e", GROUP="plugdev", MODE="0660"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6010", GROUP="plugdev", MODE="0660", TAG+="uaccess"
  '';

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

  #hardware.tenstorrent.enable = true;

  boot.binfmt.emulatedSystems = [
    "x86_64-linux"
    "i686-linux"
    "i386-linux"
  ];

  # Initrd
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "uas"
    "usb_storage"
    "sd_mod"
    "nvidia"
    "tpm_tis"
    "tpm_crb"
  ];

  # availableKernelModules only ships a module in the initrd, it never loads it.
  # Plymouth's DRM renderer needs KMS live during stage 1, so force-load these.
  boot.initrd.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_drm"
  ];

  # Firefox already had a profile here before Home Manager took over
  # profiles.ini, so name it. Without this Firefox opens an empty profile.
  ross.firefoxProfilePath = "8qp9adwe.default";
  ross.firefoxConfigPath = ".config/mozilla/firefox";

  # Backup
  # Appear on argama's dashboards. The exporter answers on the tailnet alone.
  ross.monitoring.enable = true;

  ross.backup = {
    enable = true;
    paths = [
      "/home"
      "/var/lib"
    ];
    # argama keeps its Vaultwarden repository here, below /var/lib. Without
    # this line, zeta3a sends argama's backup back to argama, which protects
    # nothing and grows with every snapshot argama takes.
    exclude = [ "/var/lib/restic-argama" ];
  };

  # Where argama sends its Vaultwarden backup. argama holds the backups of
  # every other machine, so it has nowhere of its own to put one, and a
  # password vault is the one thing on it that no rebuild can recreate.
  #
  # sftp needs the subsystem, and sshd starts that through the login shell, so
  # this account cannot have nologin. The key is root only on argama and this
  # account owns nothing but the repository directory.
  users.groups.resticremote = { };
  users.users.resticremote = {
    isSystemUser = true;
    group = "resticremote";
    description = "argama's restic repository";
    home = "/var/lib/restic-argama";
    createHome = true;
    shell = pkgs.bashInteractive;
    # No key is listed here, and none is needed. argama logs in with a
    # certificate that ssh-client-cert-resticremote renews every day. This
    # machine trusts the user authority, and AuthorizedPrincipalsFile is "none",
    # so sshd compares the principal "resticremote" against this account name.
    # See devices/argama/passwords.nix and modules/ssh-ca.nix.
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/restic-argama 0700 resticremote resticremote -"
  ];

  # No ross.remoteBuild here on purpose. This machine has 128 cores and 512GB
  # against argama's 64, so a build sent there finishes later than one kept
  # here. Nix cannot be told "local first" either: with distributedBuilds on,
  # build-remote hands a job to any matching machine that has a free slot, and
  # speedFactor only ranks the remote machines against each other. So the way
  # to keep builds on the biggest machine is to give it no builders at all.

  # Networking
  networking.hostName = "zeta3a";
  networking.hostId = "f174c9ca";

  services.openssh.enable = true;

  # A host certificate from the ssh-host-signer mount, renewed daily. argama
  # reaches this machine to write its own backup, from a timer with nobody
  # present, so a host key that nobody has accepted stops that backup. See
  # devices/argama/passwords.nix and modules/ssh-ca.nix.
  #
  # Make the first certificate by hand before the rebuild that turns this on.
  # sshd refuses to start when HostCertificate names a file that is not there.
  ross.sshCa.hostCert = true;

  # Every name a person or a timer dials. A client refuses a certificate that
  # does not carry the name it asked for, and it does not fall back to the
  # plain host key. argama uses the short name, through the zeta3a-backup alias.
  ross.sshCa.hostPrincipals = [
    "zeta3a"
    "zeta3a.nix"
    "zeta3a.tailde5a8.ts.net"
  ];

  # Graphics
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];

  boot.plymouth.enable = true;

  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "quiet"
  ];

  hardware.nvidia = {
    open = true;
    modesetting.enable = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable.overrideAttrs (
      f: p:
      let
        inherit (config.boot.kernelPackages) kernel;
      in
      {
        passthru = p.passthru // {
          open = p.passthru.open.overrideAttrs (
            f: p: {
              makeFlags = [
                "SYSSRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/source"
                "SYSOUT=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
                "MODLIB=$(out)/lib/modules/${kernel.modDirVersion}"
                "DATE="
                "TARGET_ARCH=aarch64"
                # nixpkgs sets INSTALL_MOD_STRIP=1, so modules_install runs
                # $(STRIP). The kernel Makefile defaults STRIP to
                # $(CROSS_COMPILE)strip, and CROSS_COMPILE is empty here, so
                # it runs a bare strip. That name is not in PATH: this LLVM
                # stdenv only has the target-prefixed strip. Give it the
                # absolute path, the same as common-flags.nix does for the
                # kernel itself.
                "STRIP=${lib.getExe' kernel.stdenv.cc.bintools.bintools "${kernel.stdenv.cc.targetPrefix}strip"}"
              ];
            }
          );
          settings = p.passthru.settings.overrideAttrs (
            f: p: {
              makeFlags = p.makeFlags ++ [
                "STRIP_CMD=${lib.getExe' pkgs.pkgsLLVM.stdenv.cc.bintools "${pkgs.pkgsLLVM.stdenv.cc.targetPrefix}strip"}"
              ];
            }
          );
        };
      }
    );
  };

  # Services
  services.irqbalance.enable = true;
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    # rulesProvider is a separate option and still defaults to pkgs.ananicy,
    # which nixpkgs removed. Setting only `package` leaves it dangling.
    rulesProvider = pkgs.ananicy-cpp;
  };

  services.zfs = {
    trim = {
      enable = true;
    };
    autoScrub = {
      enable = true;
      pools = [ "zpool" ];
    };
    autoSnapshot = {
      enable = true;
      frequent = 8;
      monthly = 1;
    };
  };

  # Filesystems

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
}
