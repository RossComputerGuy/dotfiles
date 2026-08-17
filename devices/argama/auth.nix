{
  config,
  lib,
  pkgs,
  ...
}:
let
  keyDir = "/run/authelia-keys";
  agent = config.detsys.vaultAgent.systemd.services.authelia-keys;
  secretPath = name: agent.secretFiles.files.${name}.path;

  # Authelia reads its secrets with LoadCredential=, which systemd resolves
  # before the unit joins the agent's namespace. PrivateTmp covers /tmp and
  # /var/tmp only, so this unit copies each secret out to /run, the same way
  # harmonia-key does in secrets.nix.
  wanted = {
    "jwt" = "secret/data/argama/authelia";
    "session" = "secret/data/argama/authelia";
    "storage" = "secret/data/argama/authelia";
  };
in
{
  #   bao kv put secret/argama/authelia \
  #     jwt=<random> session=<random> storage=<random>
  #   bao kv put secret/argama/authelia-users users=@users.yml
  detsys.vaultAgent.systemd.services.authelia-keys = {
    enable = true;
    secretFiles = {
      defaultChangeAction = "restart";
      files =
        lib.mapAttrs (field: path: {
          template = ''
            {{ with secret "${path}" }}{{ .Data.data.${field} }}{{ end }}
          '';
        }) wanted
        // {
          # The user list, with an argon2 hash for the password. Authelia opens
          # this file itself, but it lives beside the others so one unit owns the
          # whole directory.
          #
          #   authelia crypto hash generate argon2 --password <password>
          "users.yml".template = ''
            {{ with secret "secret/data/argama/authelia-users" }}{{ .Data.data.users }}{{ end }}
          '';
        };
    };
  };

  systemd.services = {
    # The sidecar must uphold authelia-keys, or the chain breaks one link
    # earlier than the line below covers: a sealed OpenBao stops the sidecar,
    # BindsTo stops authelia-keys, and its own Upholds= never gets the chance
    # to bring Authelia back. See monitoring.nix.
    detsys-vaultAgent-authelia-keys.upholds = [ "authelia-keys.service" ];

    authelia-keys = {
      description = "Publish Authelia's secrets where LoadCredential can read them";
      requiredBy = [ "authelia-main.service" ];
      before = [ "authelia-main.service" ];
      # OpenBao starts sealed and waits for an operator, so at every boot this
      # unit fails first and takes Authelia with it. Restart= cannot help: it
      # acts on a unit whose own process failed, and Authelia never ran at all.
      # Upholds= keeps Authelia running for as long as this unit is up, so the
      # unseal brings Authelia back with no operator.
      upholds = [ "authelia-main.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "authelia-keys";
        RuntimeDirectoryMode = "0750";
        RuntimeDirectoryPreserve = "yes";
        ExecStart = pkgs.writeShellScript "authelia-keys-publish" (
          let
            install = lib.getExe' pkgs.coreutils "install";
          in
          ''
            ${lib.concatMapStringsSep "\n" (n: ''
              ${install} -m 0400 ${secretPath n} ${keyDir}/${n}
            '') (builtins.attrNames wanted)}

            # Authelia opens this one itself, as its own user.
            ${install} -m 0640 -g authelia-main ${secretPath "users.yml"} ${keyDir}/users.yml
            ${lib.getExe' pkgs.coreutils "chgrp"} authelia-main ${keyDir}
          ''
        );
      };
    };

    detsys-vaultAgent-authelia-keys = {
      after = [ "openbao.service" ];
      wants = [ "openbao.service" ];
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig = {
        Restart = "always";
        RestartSec = 15;
      };
    };
  };

  services.authelia.instances.main = {
    enable = true;

    secrets = {
      jwtSecretFile = "${keyDir}/jwt";
      sessionSecretFile = "${keyDir}/session";
      storageEncryptionKeyFile = "${keyDir}/storage";
    };

    settings = {
      theme = "dark";
      # Caddy is the only way in.
      server.address = "tcp://127.0.0.1:9091";
      log.level = "info";

      authentication_backend.file.path = "${keyDir}/users.yml";

      # One cookie covers the whole zone, which is what makes one login enough
      # for every name below it.
      session.cookies = [
        {
          domain = "argama.nix";
          authelia_url = "https://auth.argama.nix";
          default_redirection_url = "https://jellyfin.argama.nix";
        }
      ];

      storage.local.path = "/var/lib/authelia-main/db.sqlite3";
      # No mail server here, so a password reset writes to a file that an
      # operator reads.
      notifier.filesystem.filename = "/var/lib/authelia-main/notification.txt";

      # The YubiKey is the second factor. Authelia asks for it, and the key is
      # already in hand for the OpenBao unseal.
      webauthn = {
        display_name = "Argama";
        # A touch proves a person is there, not only that a key is plugged in.
        user_verification = "preferred";
      };
      totp.issuer = "argama.nix";

      access_control = {
        # Nothing passes unless a rule below lets it.
        default_policy = "deny";
        rules = [
          {
            domain = "*.argama.nix";
            policy = "two_factor";
          }
        ];
      };
    };
  };
}
