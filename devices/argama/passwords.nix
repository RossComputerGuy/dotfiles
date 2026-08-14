{
  config,
  lib,
  ...
}:
{
  # Vaultwarden is the human half of the secret story. OpenBao holds what the
  # machines read, and this holds what a person types. They do not overlap:
  # OpenBao has no browser extension, no phone application and no autofill, and
  # Vaultwarden has no dynamic secrets, no PKI and no machine authentication.
  #
  # Bitwarden clients speak to this, so every platform already has an
  # application for it.
  services.vaultwarden = {
    enable = true;
    # One person and a few devices. sqlite needs no second service, and it
    # takes a plain file copy to back up.
    dbBackend = "sqlite";

    # A running Vaultwarden writes to its sqlite file continuously, so a plain
    # copy of it can be torn. This makes the backup-vaultwarden timer, which
    # takes a proper sqlite backup, and restic below copies that result rather
    # than the live file.
    #
    # This path must not begin with the data directory. The module tests a
    # string prefix, not a path one, so "/var/lib/vaultwarden-backup" fails
    # against "/var/lib/vaultwarden" even though one is not inside the other.
    backupDir = "/var/backup/vaultwarden";

    config = {
      # Caddy is the only way in, so bind the loopback.
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;

      # This has to be the address a browser uses. WebAuthn ties a credential
      # to the origin, and attachment links are built from it, so a wrong value
      # here breaks the second factor in a way that reads like a client fault.
      DOMAIN = "https://pass.argama.nix";

      # No open registration. The first account arrives by invitation from the
      # admin page, which needs the token below.
      SIGNUPS_ALLOWED = false;
      # An invitation only reaches an address in this list.
      INVITATIONS_ALLOWED = true;

      # No mail server on this machine, so an invitation cannot be delivered.
      # The admin page shows the link instead, and that is enough for a
      # household.
      SHOW_PASSWORD_HINT = false;
    };
  };

  # ADMIN_TOKEN opens the admin page, which is where the first account is
  # invited from. Vaultwarden reads it from the environment, and the agent
  # writes environment files to /run, which is not namespaced, so this works
  # where a LoadCredential= would not. Paperless takes the same route.
  #
  # Vaultwarden wants an argon2 hash and warns about a plain string. Make one
  # with "vaultwarden hash" and store the whole "$argon2id$..." output:
  #
  #   bao kv put secret/argama/vaultwarden admin_token='$argon2id$...'
  detsys.vaultAgent.systemd.services.vaultwarden = {
    enable = true;
    environment = {
      changeAction = "restart";
      template = ''
        ADMIN_TOKEN={{ with secret "secret/data/argama/vaultwarden" }}{{ .Data.data.admin_token }}{{ end }}
      '';
    };
  };

  # OpenBao starts sealed at every boot, so this unit fails first and stays
  # dead, the same as Authelia and the tunnel did. Keep it up once the token
  # arrives. See auth.nix for the longer note.
  systemd.services.detsys-vaultAgent-vaultwarden = {
    after = [ "openbao.service" ];
    wants = [ "openbao.service" ];
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      Restart = "always";
      RestartSec = 15;
    };
    upholds = [ "vaultwarden.service" ];
  };

  # This is the one thing on argama that must leave argama. Everything else
  # here comes back from a rebuild, a substituter or a re-download. A password
  # vault does not, and argama cannot be its own answer because it is the
  # machine the copy has to survive.
  #
  # The address of the repository is not written here on purpose. It comes from
  # OpenBao, so the target changes without a rebuild, and the same unit serves
  # an sftp repository on another machine, an object store, or a disk that gets
  # carried off site.
  #
  #   bao kv put secret/argama/vaultwarden-backup \
  #     repository=sftp:ross@zeta3a:/tank/vaultwarden password=<a long one>
  #
  # An sftp target also needs a key that argama can use without a person, and
  # zeta3a has to accept it. There is no path for that in this configuration
  # yet.
  #
  # Keep this password somewhere that is not the vault it protects. A password
  # written only in Vaultwarden cannot open the backup of Vaultwarden.
  detsys.vaultAgent.systemd.services."restic-backups-vaultwarden" = {
    enable = true;
    environment = {
      # A changed password must not stop a backup that is running.
      changeAction = "none";
      template = ''
        RESTIC_REPOSITORY={{ with secret "secret/data/argama/vaultwarden-backup" }}{{ .Data.data.repository }}{{ end }}
        RESTIC_PASSWORD={{ with secret "secret/data/argama/vaultwarden-backup" }}{{ .Data.data.password }}{{ end }}
      '';
    };
  };

  services.restic.backups.vaultwarden = {
    paths = [
      # The consistent copy of the database.
      "/var/backup/vaultwarden"
      # Attachments, sends, and the key that signs the tokens. None of these
      # are in the database.
      "/var/lib/vaultwarden"
    ];
    exclude = [
      # The live database. The copy above is the one that is safe to read.
      "/var/lib/vaultwarden/db.sqlite3*"
    ];
    environmentFile = "/run/keys/environment/restic-backups-vaultwarden/EnvFile";
    initialize = true;
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
    # This repository belongs to argama, unlike the append only one the clients
    # push to, so this machine can prune its own history.
    pruneOpts = [
      "--keep-daily 14"
      "--keep-weekly 8"
      "--keep-monthly 12"
    ];
  };

  systemd.services.restic-backups-vaultwarden = {
    # Take the sqlite copy first, or the newest snapshot holds yesterday's
    # database.
    after = [ "backup-vaultwarden.service" ];
    wants = [ "backup-vaultwarden.service" ];
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "10m";
    };
  };

  # No port is open here. Caddy publishes pass.argama.nix. See web.nix.
}
