# Blast-radius sandbox for OpenCode: a qemu microVM that runs `opencode`
# against the caller's CWD, shared in at launch as 9p tag "workspace". The agent
# can't touch the host beyond that one share. Per-user state lives on a
# persistent ext4 volume inside the VM, not on the host.
#
# Networking is qemu user-mode (slirp): outbound DHCP+NAT+DNS with zero host
# config, plus a hostfwd from 127.0.0.1:2222 to the guest's sshd. The host
# `opencode` wrapper ssh's in for a proper PTY (so opencode's TUI renders
# and resizes), authorizing itself with an ephemeral key shared in read-only as
# 9p tag "sandboxctl".
{
  config,
  lib,
  pkgs,
  ...
}:
let
  oc = import ../users/ross/opencode-config.nix {
    inherit pkgs lib;
    baseURL = "http://10.0.2.2:5000/v1";
  };
  configFile = pkgs.writeText "opencode.json" (builtins.toJSON oc.settings);
  servePort = 4096;
in
{
  networking.hostName = "opencode";
  system.stateVersion = "24.11";
  nixpkgs.config.allowUnfree = true; # harmless; some toolchain deps are unfree

  microvm = {
    hypervisor = "qemu";
    vcpu = 8;
    mem = 8192;

    # Ship the store as a read-only disk image (self-contained; no host-store
    # share). Writable overlay lets the guest realize derivations (nix build)
    # inside; it persists in the wrapper's per-user state dir, caching downloads
    # between sessions.
    storeOnDisk = true;
    writableStoreOverlay = "/nix/.rw-store";
    volumes = [
      {
        image = "nix-store-overlay.img";
        mountPoint = config.microvm.writableStoreOverlay;
        size = 8192;
      }
      # Persistent root home on a real ext4 volume (not 9p): opencode's state
      # and session history under ~/.local/share/opencode persist across runs.
      # 9p shares don't persist writes well, which is why this is a real volume.
      # The session runs as root (see below), so HOME is /root.
      {
        image = "home.img";
        mountPoint = "/root";
        size = 2048;
      }
    ];

    # qemu user-mode networking: outbound DHCP+NAT+DNS, no host setup needed.
    interfaces = [
      {
        type = "user";
        id = "qemu";
        mac = "02:00:00:01:01:01";
      }
    ];

    # Forward host 127.0.0.1:2222 -> guest sshd (slirp's fixed guest IP is
    # 10.0.2.15). microvm.nix adds this as a hostfwd on the user netdev. One
    # sandbox runs at a time, so a fixed host port is fine.
    forwardPorts = [
      {
        from = "host";
        proto = "tcp";
        host.address = "127.0.0.1";
        host.port = 2222;
        guest.address = "10.0.2.15";
        guest.port = 22;
      }
      {
        from = "host";
        proto = "tcp";
        host.address = "127.0.0.1";
        host.port = servePort;
        guest.address = "10.0.2.15";
        guest.port = servePort;
      }
    ];

    # Attach the caller's CWD ("workspace") and the wrapper's control dir holding
    # the ephemeral ssh pubkey ("sandboxctl", read-only) as 9p shares at launch.
    # microvm.nix inlines this into `runtime_args=$(...)` and appends the result
    # to the qemu args; the wrapper passes the paths via env. This mirrors
    # microvm.nix's own 9p wiring (-fsdev + virtio-9p-pci), just per-launch.
    # (The supported hook — exporting $runtime_args directly doesn't work, the
    # runner resets it before exec.)
    extraArgsScript = ''
      if [ -n "''${OPENCODE_SANDBOX_WS:-}" ]; then
        echo "-fsdev local,id=fsws,path=''${OPENCODE_SANDBOX_WS},security_model=none,readonly=off"
        echo "-device virtio-9p-pci,fsdev=fsws,mount_tag=workspace"
      fi
      if [ -n "''${OPENCODE_SANDBOX_CTL:-}" ]; then
        echo "-fsdev local,id=fsctl,path=''${OPENCODE_SANDBOX_CTL},security_model=none,readonly=on"
        echo "-device virtio-9p-pci,fsdev=fsctl,mount_tag=sandboxctl"
      fi
    '';
  };

  # The caller's CWD. No cache=loose: keep host/guest file views consistent so
  # the agent's edits are immediately visible on the host and vice versa.
  fileSystems."/workspace" = {
    device = "workspace";
    fsType = "9p";
    options = [
      "trans=virtio"
      "version=9p2000.L"
      "msize=65536" # matches microvm.nix's own 9p mounts
      # Rootless qemu's security_model=none maps the qemu-process owner (the host
      # caller) to guest-root, so the share appears owned by root in the guest.
      # The session runs as root, so it has full read/write; host-side writes
      # land owned by the caller. access=client keeps perm checks on the guest.
      "access=client"
      "x-systemd.after=systemd-modules-load.service"
      "nofail"
    ];
  };

  # Read-only control channel: the host wrapper drops the run's ssh pubkey here.
  fileSystems."/sandboxctl" = {
    device = "sandboxctl";
    fsType = "9p";
    options = [
      "trans=virtio"
      "version=9p2000.L"
      "msize=65536"
      "access=client"
      "ro"
      "x-systemd.after=systemd-modules-load.service"
      "nofail"
    ];
  };

  # qemu user-net hands out address/gateway/DNS over DHCP.
  networking.useDHCP = false;
  networking.useNetworkd = true;
  services.resolved.enable = true;
  systemd.network.networks."10-lan" = {
    matchConfig.Type = "ether";
    networkConfig.DHCP = "yes";
  };

  # SSH-in is how the host drives opencode (proper PTY). Pubkey-only, as root —
  # root maps to the host caller over 9p, giving full workspace access.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };
  networking.firewall.allowedTCPPorts = [
    22
    servePort
  ];

  systemd.services.opencode-serve = {
    description = "OpenCode headless server (remote control)";
    wantedBy = [ "multi-user.target" ];
    after = [
      "workspace.mount"
      "sandboxctl.mount"
      "network-online.target"
    ];
    wants = [ "network-online.target" ];
    requires = [ "sandboxctl.mount" ];
    unitConfig = {
      ConditionPathIsMountPoint = "/workspace";
      ConditionPathExists = "/sandboxctl/serve-env";
    };
    environment = {
      HOME = "/root";
      OPENCODE_CONFIG = "${configFile}";
    };
    serviceConfig = {
      EnvironmentFile = "/sandboxctl/serve-env";
      ExecStart = "${pkgs.opencode}/bin/opencode serve --hostname 0.0.0.0 --port ${toString servePort}";
      WorkingDirectory = "/workspace";
      Restart = "on-failure";
    };
  };

  # Install the run's authorized key (from the read-only control share) into
  # root's home before sshd starts accepting connections. Ordered after the
  # /root volume mount so the key lands on the persistent volume.
  systemd.services.opencode-authorized-key = {
    description = "Install opencode ssh authorized key";
    wantedBy = [ "multi-user.target" ];
    before = [ "sshd.service" ];
    after = [
      "sandboxctl.mount"
      "root.mount"
    ];
    requires = [ "sandboxctl.mount" ];
    unitConfig.ConditionPathExists = "/sandboxctl/authorized_keys";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -m 700 -o root -g root /root/.ssh
      install -m 600 -o root -g root /sandboxctl/authorized_keys /root/.ssh/authorized_keys
    '';
  };

  # Console autologin for debugging; opencode is launched over ssh, not here.
  services.getty.autologinUser = "root";

  environment.systemPackages =
    with pkgs;
    [
      opencode
      git
    ]
    ++ oc.lspPackages;

  environment.variables.OPENCODE_CONFIG = configFile;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [ "https://cache.nixos.org" ];
    trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
  };
}
