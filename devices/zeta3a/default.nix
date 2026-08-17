{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  llamaModels = import ../../users/ross/opencode-models.nix;
  mmprojF16 = pkgs.fetchurl {
    url = "https://huggingface.co/unsloth/Qwen3.6-35B-A3B-GGUF/resolve/main/mmproj-F16.gguf";
    hash = "sha256-iXHuTzMf8KTGCTdPMphLPU5twIbAqjXx1jf60YKeiH8=";
  };
  # zeta3a-only server tuning (the 12GB RTX 5070 can't hold vision at 135k ctx).
  # Vision models get a trimmed context + smaller batch so the projector fits.
  llamaModelOverrides = {
    "qwen3.6:35b-a3b-heretic" = {
      mmproj = toString mmprojF16;
      ctx-size = 16384;
      batch-size = 1024;
      ubatch-size = 512;
    };
    # GLM-5.2 744B: cpu-moe keeps the experts in RAM, but offloading every
    # layer's attention overflows the 12GB 5070 (~15.4GB weight buffer). Decode
    # is expert-bound on CPU, so GPU attention layers barely dent t/s, but they
    # help prefill for free. Raise n-gpu-layers until VRAM is nearly full.
    "glm5.2:744b-a40b" = {
      n-gpu-layers = 20;
      ctx-size = 32768;
      batch-size = 512;
      ubatch-size = 512;
    };
    # DeepSeek-V4-Flash: the 135k default ctx at 4096 ubatch wants a ~70GB CUDA
    # compute buffer and OOMs the 12GB card. Cap it like GLM to get a clean
    # load. cpu-moe keeps experts in RAM, so n-gpu-layers only offloads the MLA
    # attention and dense gate (the "router in vram" bit). Start conservative,
    # then raise n-gpu-layers and ctx once we see real VRAM headroom on load.
    "deepseek-v4-flash:q4" = {
      # DSpark speculative decoding. The trained drafter proposes a block of
      # tokens, the target verifies them in one batched pass. Target decode is
      # remote-NUMA latency-bound (~3.6 t/s), so amortizing many tokens over one
      # verify is the whole lever. The drafter MUST run on GPU (spec-draft-ngl):
      # on CPU it would read weights/token from remote RAM and lose.
      # The drafter arch upstream expects is "dflash" (b10209 registers it);
      # YanissAmz's bf16 GGUF uses that arch. It is 10.9GB, so give it the whole
      # 12GB card: target n-gpu-layers=0 (cpu-moe already keeps experts in RAM,
      # and decode is expert-bound, so GPU attention was not helping decode).
      # NOTE: the DeepSeek-V4 target-side dspark port is not in master yet (PR
      # 25683), so if the target fails to feed hidden states we pin YanissAmz's
      # llama.cpp fork (dspark-dsv4 branch) instead.
      # DSpark is not viable on this box (12GB 5070 + ARM CPU). See the
      # zeta3a-dspark-dead-end memory. The only drafter is a DeepSeek-V4-backbone
      # MoE: its experts are mxfp4 (10.4GB, will not fit the card next to the
      # target) and its sparse-indexer + sinkhorn attention is too heavy for the
      # ARM CPU. Every config lost badly to plain decode: mxfp4/GPU OOMs,
      # mxfp4/CPU 0.18 t/s, and even after reformatting the experts to a
      # CPU-fast Q4_K it was 0.19 (split) / 0.15 (all-CPU) t/s, because the
      # bottleneck is the draft attention, not the expert kernel. Plain Q4.
      # n-gpu-layers=0: the router keeps other models (e.g. GLM-4.7-Flash, ~9GB
      # VRAM) resident, so DeepSeek must coexist on the 12GB card. Its decode is
      # CPU-expert-bound (GPU attention only helped prefill), so give the GPU to
      # the small fast models and run DeepSeek attention on CPU. Costs a bit of
      # prefill, keeps decode ~3.6 t/s, and never OOMs against a resident GLM.
      n-gpu-layers = 0;
      ctx-size = 32768;
      batch-size = 512;
      ubatch-size = 512;
    };
    # GLM-4.7-Flash: the fast daily model, kept resident on the GPU with all
    # attention offloaded (n-gpu-layers=999 from the shared defaults). It uses
    # MLA (kv_lora_rank 512, 47 layers), so llama.cpp stores a compressed KV
    # cache of about 53 KiB per token. At the shared 135168 ctx that is ~7.3GB,
    # and with the attention weights (~1.8GB), the 4096-ubatch compute buffer
    # (1.68GB), and the desktop (~1.8GB) it overflows the 12GB card. It only
    # loaded before because fit auto-shrank the context. fit is off now (the big
    # cpu-moe models need it off), so this model must cap its own context. 65536
    # holds ~3.6GB of KV and leaves headroom for the compute buffer and a second
    # model. ubatch 2048 halves the compute buffer and keeps prefill fast.
    "glm4.7-flash:30b-a3b" = {
      ctx-size = 65536;
      batch-size = 2048;
      ubatch-size = 2048;
    };
  };
  # These are per-model tunables, deliberately NOT in services.llama-cpp.settings.
  # llama.cpp's router overlays its own CLI args on top of every child preset
  # (server-models.cpp: preset.merge(base_preset)), so anything passed on the
  # router CLI clobbers per-model INI values. Keeping them out of the router CLI
  # and injecting them as preset defaults lets the per-model overrides above win.
  llamaSharedDefaults = {
    n-gpu-layers = 999;
    ctx-size = 135168;
    batch-size = 4096;
    ubatch-size = 4096;
  };
  llamaModelsPreset = pkgs.writeText "llama-models.ini" (
    lib.generators.toINI { } (
      lib.mapAttrs (
        name: m:
        llamaSharedDefaults // m.preset // (llamaModelOverrides.${name} or { }) // { alias = name; }
      ) llamaModels
    )
  );

  mcpServers = import ../../users/ross/mcp-servers.nix { inherit pkgs lib; };
  globalMcp = lib.filterAttrs (_: s: s.scope == "global") mcpServers;
  mcpUiConfig = builtins.toJSON {
    mcpServers = builtins.toJSON (
      lib.mapAttrsToList (name: _: {
        inherit name;
        url = "http://127.0.0.1:5002/servers/${name}/mcp";
        enabled = true;
        useProxy = true;
      }) globalMcp
    );
  };
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

  services.llama-cpp = {
    enable = true;
    package = (pkgs.llama-cpp.override { cudaSupport = true; }).overrideAttrs (old: {
      # Pinned past nixpkgs' 9925 to upstream b10209 (newest at the time). We
      # briefly ran YanissAmz's dspark-dsv4 fork to try DSpark speculative
      # decoding for DeepSeek-V4-Flash, but it is not viable on this box (see the
      # zeta3a-dspark-dead-end memory), so we are back on stock upstream. The
      # version bump moves the bundled webui npm lockfile (npmRoot=tools/ui), so
      # npmDepsHash moves with it (prefetch-npm-deps on b10209 tools/ui lockfile).
      version = "10209";
      npmDepsHash = "sha256-B7uEynAG70a3xauBKc20RuFa9cnWaWzVBCh+LPLBnIM=";
      src = pkgs.fetchFromGitHub {
        owner = "ggml-org";
        repo = "llama.cpp";
        tag = "b10209";
        hash = "sha256-5w9IyT2xBTfzea51zovg0TzsBDk6jL5Td3ax8pjYNjw=";
      };
      NVCC_APPEND_FLAGS = "-ccbin ${pkgs.gcc13}/bin/g++";
    });
    settings = {
      host = "127.0.0.1";
      port = 5001;
      models-preset = llamaModelsPreset;
      parallel = 1;
      flash-attn = "on";
      jinja = true;
      no-mmap = true;
      # Decode wants NUMA-node-aligned thread counts. llama-bench IQ1_S sweep:
      # tg 16->1.05, 24->1.42, 32->1.57, 48->0.99 (1.5 nodes, misaligned), 64->1.61.
      # Decode plateaus ~1.6 from 24-64, so it is NOT thread-bound past this, it
      # is NUMA-remote-bound (experts scattered over 4 nodes, 197GB can't fit one
      # node). 64 = 2 nodes ties 32 on decode but roughly doubles prefill, so use
      # it. 128 (all 4 nodes) oversubscribes the barrier and craters to ~0.5.
      # Keep the full 128 for prefill (compute-bound, scales with cores).
      threads = 64;
      threads-batch = 128;
      # 4 NUMA nodes (32 cores each). Without this, threads read expert weights
      # mostly from remote nodes and effective bandwidth (and t/s) craters.
      numa = "distribute";
      reasoning = "on";
      api-key = "local";
      temp = 0.6;
      top-p = 0.95;
      min-p = 0.0;
      top-k = 20;
      fit = "off";
      # batch-size / ubatch-size / ctx-size / n-gpu-layers are set per-model in
      # the preset INI (see llamaSharedDefaults / llamaModelOverrides). Passing
      # them here would let the router override every child's per-model value.
      cpu-moe = true;
      tools = "read_file,file_glob_search,grep_search,get_datetime";
      ui-mcp-proxy = true;
      ui-config-file = pkgs.writeText "llama-ui-config.json" mcpUiConfig;
    };
  };

  systemd.services.mcp-proxy = {
    bindsTo = [ "llama-cpp.service" ];
    after = [ "llama-cpp.service" ];
    wantedBy = [ "llama-cpp.service" ];
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

  systemd.services.llama-cpp = {
    wantedBy = lib.mkForce [ ];
    unitConfig.StopWhenUnneeded = true;
    serviceConfig = {
      MemoryDenyWriteExecute = lib.mkForce false;
      TimeoutStartSec = "5min";
      ExecStartPost = pkgs.writeShellScript "llama-cpp-wait" ''
        miss=0
        for _ in $(${lib.getExe' pkgs.coreutils "seq"} 1 90); do
          status=$(${lib.getExe pkgs.curl} -s -o /dev/null -w '%{http_code}' --max-time 2 http://127.0.0.1:5001/health || true)
          [ "$status" = "200" ] && exit 0
          if [ "$status" = "000" ]; then
            miss=$((miss + 1))
            [ "$miss" -ge 10 ] && exit 1
          else
            miss=0
          fi
          ${lib.getExe' pkgs.coreutils "sleep"} 1
        done
        exit 1
      '';
    };
  };

  systemd.sockets.llama-cpp-proxy = {
    wantedBy = [ "sockets.target" ];
    socketConfig.ListenStream = "0.0.0.0:5000";
  };

  systemd.services.llama-cpp-proxy = {
    requires = [ "llama-cpp.service" ];
    after = [ "llama-cpp.service" ];
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
  ross.backup = {
    enable = true;
    paths = [
      "/home"
      "/var/lib"
    ];
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
    # argama logs in with a certificate now. This machine trusts the user
    # authority, and AuthorizedPrincipalsFile is "none", so sshd compares the
    # principal "resticremote" against this account name. See
    # devices/argama/passwords.nix and modules/ssh-ca.nix.
    #
    # The pasted key stays until the certificate has carried one backup. Remove
    # it after that, together with /root/.ssh/zeta3a-backup on argama. A backup
    # that fails is quiet, so do not remove both at the same time.
    openssh.authorizedKeys.keys = [
      # argama, /root/.ssh/zeta3a-backup.pub
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILz9sV1yfoAMg3ow0N4ogApGE8R/Ff/HmOTXA3a65SMY root@argama"
    ];
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
