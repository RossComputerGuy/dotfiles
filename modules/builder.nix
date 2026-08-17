{
  config,
  lib,
  ...
}:
let
  cfg = config.ross.remoteBuild;
in
{
  options.ross.remoteBuild = {
    enable = lib.mkEnableOption "sending builds to argama";

    publicHostKey = lib.mkOption {
      description = ''
        argama's ssh host key, base64 encoded, as
        `ssh-keyscan -t ed25519 argama | grep -v '^#' | cut -d' ' -f3`.

        Leave it null and the first connection accepts whatever key answers.
        Set it and a machine that is not argama cannot pretend to be a builder
        this machine already trusts.
      '';
      type = lib.types.nullOr lib.types.str;
      default = null;
    };

    sshKey = lib.mkOption {
      description = ''
        The private key that reaches the nixremote account on argama.

        This one file stays on disk, unlike every other secret here, and the
        reason is ordering. The nix daemon reads it before OpenBao is unsealed,
        because a rebuild is often the first thing that happens after a boot.
        A key that arrives later would make every build fail until an operator
        turned up, which is worse than a build credential on a root only file.

        The better answer is a certificate. Set `ross.sshCa.clientCerts` to
        `[ "nixremote" ]` and point this at
        `/var/lib/ssh-client-cert/nixremote`. The key is then made on the
        machine and never travels, argama needs no pasted key, and OpenSSH
        finds the certificate beside it with no configuration. It keeps the
        ordering property too: the key and the last certificate both survive a
        reboot, and the certificate lives 30 days, so only OpenBao that stays
        sealed for a month stops a build.

        Without the certificate, make one key per machine and give the public
        half to argama by hand:

          ssh-keygen -t ed25519 -N "" -f /root/.ssh/argama-builder
      '';
      type = lib.types.str;
      default = "/root/.ssh/argama-builder";
    };
  };

  config = lib.mkIf cfg.enable {
    # argama does not send builds to itself.
    assertions = [
      {
        assertion = config.networking.hostName != "argama";
        message = "ross.remoteBuild sends builds to argama, so argama must not enable it.";
      }
    ];

    nix.distributedBuilds = true;

    nix.buildMachines = [
      {
        hostName = "argama";
        # The name resolves on the tailnet, so this works away from the house.
        systems = [ "aarch64-linux" ];
        protocol = "ssh-ng";
        # argama runs 8 jobs of 8 cores. The same number here, so one machine
        # cannot ask for more than argama is willing to run.
        maxJobs = 8;
        # 64 cores against a workstation. Prefer argama when both could take
        # the work.
        speedFactor = 4;
        sshUser = "nixremote";
        inherit (cfg) sshKey publicHostKey;
        supportedFeatures = [
          "big-parallel"
          "kvm"
          "nixos-test"
          "benchmark"
        ];
      }
    ];

    # Let argama fetch a dependency from a cache itself, instead of this machine
    # downloading it and pushing it over the link. argama is the cache, so this
    # turns most of the copying into no copying at all.
    nix.settings.builders-use-substitutes = true;
  };
}
