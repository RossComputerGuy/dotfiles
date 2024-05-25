{ config, lib, pkgs, ... }:
let
  box64' = pkgs.box64.overrideAttrs (f: p: {
    cmakeFlags = p.cmakeFlags ++ [
      "-DM1=ON"
    ];
  });

  virglrenderer' = pkgs.virglrenderer.overrideAttrs (f: p: {
    version = "git+84efb186c1dacc0838770027f73a09d065a5bbdf";

    src = pkgs.fetchurl {
      url = "https://gitlab.freedesktop.org/slp/virglrenderer/-/archive/84efb186c1dacc0838770027f73a09d065a5bbdf/virglrenderer-84efb186c1dacc0838770027f73a09d065a5bbdf.tar.bz2";
      hash = "sha256-fskcDk5agQhc1GI0f8m920gBoQPfh3rXb/5ZxwKSLaA=";
    };

    mesonFlags = [
      "-Ddrm-msm-experimental=true"
      "-Ddrm-asahi-experimental=true"
    ];
  });

  krunvm' = (pkgs.krunvm.override {
    libkrun = (pkgs.libkrun.override {
      libkrunfw = pkgs.libkrunfw.overrideAttrs (f: p: {
        version = "git+bb1506b92ed78da880fc1a2f0e1180040f1a7a36";

        src = pkgs.fetchFromGitHub {
          owner = "containers";
          repo = f.pname;
          rev = "bb1506b92ed78da880fc1a2f0e1180040f1a7a36";
          hash = "sha256-BN6v33iKgs+7n3ITaeERVg3S06xdQMH7PIAYtRpQ7UU=";
        };

        kernelSrc = pkgs.fetchurl {
          url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.22.tar.xz";
          hash = "sha256-I+PntWQHJQ9UEb2rlXY9C8TjoZ36Qx2VHffqyr1hovQ=";
        };

        nativeBuildInputs = p.nativeBuildInputs ++ (with pkgs; [ perl openssl ]);

        postPatch = p.postPatch + ''
          cp ${config.boot.kernelPackages.kernel.configfile} config-libkrunfw_aarch64
        '';

        meta.platforms = p.meta.platforms ++ [ "aarch64-linux" ];
      });
    }).overrideAttrs (f: p: {
      version = "git+0bea04816f4dc414a947aa7675e169cbbfbd45dc";

      src = pkgs.fetchFromGitHub {
        owner = "containers";
        repo = f.pname;
        rev = "0bea04816f4dc414a947aa7675e169cbbfbd45dc";
        hash = "sha256-eo48jhc6L92+ycSMwBtFO0qhbtanx+SXm1eJgYlsass=";
      };

      nativeBuildInputs = p.nativeBuildInputs ++ (with pkgs; [
        pkg-config
        llvmPackages_latest.clang
      ]);

      buildInputs = p.buildInputs ++ (with pkgs; [
        libepoxy
        libdrm
        pipewire
        virglrenderer'
      ]);

      env.LIBCLANG_PATH = "${pkgs.llvmPackages_latest.clang-unwrapped.lib}/lib/libclang.so";

      cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
        inherit (f) src;
        hash = "sha256-Mj0GceQBiGCt0KPXp3StjnuzWhvBNxdSUCoroM2awIY=";
      };

      makeFlags = p.makeFlags ++ [
        "GPU=1"
        "SND=1"
      ];
    });
  }).overrideAttrs (f: p: {
    version = "git+5494d84a66bee3b802a0392cf8d662158ac7287d";

    src = pkgs.fetchFromGitHub {
      owner = "containers";
      repo = f.pname;
      rev = "5494d84a66bee3b802a0392cf8d662158ac7287d";
      hash = "sha256-BfNRGMiA8CigYvsNnMz5Lqj2l0xMu833tLcB80WmFFU=";
    };

    cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
      inherit (f) src;
      hash = "sha256-yie39jVAH0N+5ZBTv+1NzNV+CJoDadF1nNWrirCfEBc=";
    };
  });
in
{
  imports = [
    ../../system/linux/desktop.nix
    ./steam.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  boot.binfmt = {
    emulatedSystems = [
      "x86_64-linux"
      "i686-linux"
      "i386-linux"
    ];
    registrations = {
      i686-linux.interpreter = lib.mkForce (lib.getExe box64');
      x86_64-linux.interpreter = lib.mkForce (lib.getExe box64');
    };
  };

  boot.kernelPatches = [{
    name = "waydroid";
    patch = null;
    extraConfig = ''
      ANDROID_BINDER_IPC y
      ANDROID_BINDERFS y
      ANDROID_BINDER_DEVICES binder,hwbinder,vndbinder
      ASHMEM y
      ANDROID_BINDERFS y
      ANDROID_BINDER_IPC y
    '';
  }];

  environment = {
    etc."containers/policy.json".text = builtins.toJSON {
      default = [{ type = "insecureAcceptAnything"; }];
    };
    systemPackages = with pkgs; [
      openscad
      mpv
      vlc
      box64'
      krunvm'
      buildah
      passt
      virglrenderer'
    ];
  };

  programs.firefox.enable = true;

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

  home-manager.users.ross.wayland.windowManager.hyprland.package = pkgs.hyprland-legacy-renderer;
  home-manager.users.ross.xdg.configFile."kanshi/config".source = ./config/kanshi/config;
}
