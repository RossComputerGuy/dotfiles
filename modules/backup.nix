{
  config,
  lib,
  ...
}:
let
  cfg = config.ross.backup;
  agent = config.detsys.vaultAgent.systemd.services."restic-backups-argama";
  # The agent writes its environment file below /run, which no PrivateTmp
  # covers, so the restic unit reads it as a normal EnvironmentFile.
  envFile = "/run/keys/environment/restic-backups-argama/EnvFile";
in
{
  options.ross.backup = {
    enable = lib.mkEnableOption "a nightly restic backup to argama";

    paths = lib.mkOption {
      description = ''
        The directories to back up.

        The Nix store is not here on purpose. Every path in it comes back from a
        build or from a substituter, so a copy holds no information that the
        flake does not hold already.
      '';
      type = lib.types.listOf lib.types.str;
      default = [
        "/home"
        "/var/lib"
      ];
    };

    exclude = lib.mkOption {
      description = "Patterns that the backup passes over.";
      type = lib.types.listOf lib.types.str;
      default = [
        "/home/*/.cache"
        "/home/*/.local/share/Trash"
        "/var/lib/systemd/coredump"
      ];
    };
  };

  config = lib.mkIf cfg.enable {
    # Everything this machine needs comes from OpenBao: the repository address,
    # the repository password, and the certificate authority that signs
    # backup.argama.nix. Nothing is on this disk except the AppRole files.
    #
    #   bao kv put secret/${config.networking.hostName}/restic \
    #     repository=rest:https://<user>:<pass>@backup.argama.nix/ password=<password>
    #   bao kv put secret/argama/ca certificate=@root.crt
    #
    # The agent reaches OpenBao over the tailnet on plain HTTP, not through
    # https://vault.argama.nix. That name is signed by argama's own authority,
    # and this machine cannot check that signature until it has the certificate
    # it is asking OpenBao for. Tailscale encrypts the link, so the plain port
    # is what breaks the circle.
    #
    # agentConfig replaces defaultAgentConfig completely, so the auto_auth block
    # has to be here and not only in the default.
    detsys.vaultAgent.systemd.services."restic-backups-argama" = {
      enable = true;
      agentConfig = {
        vault.address = "http://argama:8200";
        auto_auth.method = [
          {
            type = "approle";
            config = {
              role_id_file_path = "/var/lib/vault-agent/role-id";
              secret_id_file_path = "/var/lib/vault-agent/secret-id";
              remove_secret_id_file_after_reading = false;
            };
          }
        ];
      };

      # restic runs inside the agent's namespace, so it reads this file straight
      # out of PrivateTmp. RESTIC_CACERT below points at it.
      secretFiles.files."argama-ca.crt" = {
        changeAction = "none";
        template = ''
          {{ with secret "secret/data/argama/ca" }}{{ .Data.data.certificate }}{{ end }}
        '';
      };

      environment = {
        # A changed password must not stop a backup that is running.
        changeAction = "none";
        template = ''
          RESTIC_REPOSITORY={{ with secret "secret/data/${config.networking.hostName}/restic" }}{{ .Data.data.repository }}{{ end }}
          RESTIC_PASSWORD={{ with secret "secret/data/${config.networking.hostName}/restic" }}{{ .Data.data.password }}{{ end }}
          RESTIC_CACERT=${agent.secretFiles.files."argama-ca.crt".path}
        '';
      };
    };

    services.restic.backups.argama = {
      inherit (cfg) paths exclude;
      # The module takes this in place of repository and passwordFile, and it
      # satisfies both of its assertions.
      environmentFile = envFile;
      initialize = true;
      timerConfig = {
        OnCalendar = "daily";
        # Each machine starts at a different minute, so they do not all reach
        # argama together.
        RandomizedDelaySec = "2h";
        Persistent = true;
      };
      # pruneOpts stays empty. The server is append only, so a client cannot
      # remove a snapshot even from its own repository. argama prunes instead,
      # in its own devices/argama/backup.nix.
    };

    systemd.services.restic-backups-argama.serviceConfig = {
      Restart = "on-failure";
      RestartSec = "10m";
    };
  };
}
