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
  };
  llamaModelsPreset = pkgs.writeText "llama-models.ini" (
    lib.generators.toINI { } (
      lib.mapAttrs (
        name: m: m.preset // (llamaModelOverrides.${name} or { }) // { alias = name; }
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
    nvtopPackages.nvidia
    dsview
  ];

  services.llama-cpp = {
    enable = true;
    package = pkgs.llama-cpp.override { cudaSupport = true; };
    settings = {
      host = "127.0.0.1";
      port = 5001;
      models-preset = llamaModelsPreset;
      parallel = 1;
      flash-attn = "on";
      jinja = true;
      no-mmap = true;
      threads = 128;
      reasoning = "on";
      api-key = "local";
      temp = 0.6;
      top-p = 0.95;
      min-p = 0.0;
      top-k = 20;
      fit = "off";
      batch-size = 4096;
      ubatch-size = 4096;
      ctx-size = 135168;
      n-gpu-layers = 999;
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

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
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
  ];

  # Networking
  networking.hostName = "zeta3a";
  networking.hostId = "f174c9ca";

  services.openssh.enable = true;

  # Graphics
  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];

  boot.kernelParams = [
    "nvidia-drm.modeset=1"
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
  services.ananicy.enable = true;

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
    options = [ "zfsutil" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "vfat";
  };

  fileSystems."/nix" = {
    device = "zpool/nix";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  fileSystems."/home" = {
    device = "zpool/home";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };

  fileSystems."/var" = {
    device = "zpool/var";
    fsType = "zfs";
    options = [ "zfsutil" ];
  };
}
