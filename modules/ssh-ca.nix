{
  config,
  lib,
  pkgs,
  ...
}:
let
  userCa = ../certs/ssh-user-ca.pub;
  hostCa = ../certs/ssh-host-ca.pub;
  # A missing path is an evaluation error and not a warning, so read each file
  # only when it is there. Every machine keeps building until an operator adds
  # them. modules/pki.nix does the same for the TLS root.
  userPresent = builtins.pathExists userCa;
  hostPresent = builtins.pathExists hostCa;
in
{
  options.ross.sshCa.hostCert = lib.mkEnableOption ''
    a host certificate from argama, renewed daily.

    Turn this on only after certs/ssh-host-ca.pub is in the repository and the
    ssh-host-signer mount answers. sshd refuses to start when HostCertificate
    names a file that is not there, so a machine that turns this on too early
    loses sshd at its next restart'';

  options.ross.sshCa.hostPrincipals = lib.mkOption {
    description = ''
      The names this machine's host certificate is good for.

      A client compares the name it dialled against this list, so a name that is
      not here gives an error that reads like a wrong key. The short name covers
      "ssh argama" over the tailnet. Add the full tailnet name as well if you
      reach a machine that way.

      Do not put <hostName>.argama.nix here. argama.nix is the zone of the web
      services, and no machine answers to its own name inside it.
    '';
    type = lib.types.listOf lib.types.str;
    default = [ config.networking.hostName ];
    defaultText = lib.literalExpression "[ config.networking.hostName ]";
    example = [
      "argama"
      "argama.tail1234.ts.net"
    ];
  };

  options.ross.sshCa.clientCerts = lib.mkOption {
    description = ''
      The OpenBao roles this machine asks a client certificate for.

      Each name makes a key at /var/lib/ssh-client-cert/<name> on the first run
      and keeps a certificate beside it. Point an ssh IdentityFile at the key
      and OpenSSH finds the certificate by itself.
    '';
    type = lib.types.listOf lib.types.str;
    default = [ ];
    example = [ "nixremote" ];
  };

  config = {
    # argama runs two SSH certificate authorities in OpenBao. One signs the keys
    # of people, the other signs the host keys of machines. They are separate
    # because an authority that could do both would let an attacker who took the
    # user authority pretend to be argama to the whole fleet.
    #
    # Both public keys belong in the repository. Only the private halves matter,
    # and those never leave OpenBao. A machine can therefore trust the fleet
    # before it has ever spoken to argama.
    #
    # Put them there with, on argama:
    #   bao read -field=public_key ssh-client-signer/config/ca > certs/ssh-user-ca.pub
    #   bao read -field=public_key ssh-host-signer/config/ca > certs/ssh-host-ca.pub

    # sshd accepts a certificate signed by this authority. This adds to
    # authorized_keys and replaces nothing, so a static key keeps working.
    services.openssh.settings.TrustedUserCAKeys = lib.mkIf userPresent "${userCa}";

    # One line covers every machine. The pattern is "*" because this authority
    # signs only the hosts of this fleet, so a name it did not sign cannot match
    # whatever the pattern says.
    programs.ssh.knownHosts.argama-host-ca = lib.mkIf hostPresent {
      certAuthority = true;
      extraHostNames = [ "*" ];
      publicKeyFile = hostCa;
    };

    # The command a person runs on a new device. It needs a token, so run
    # "bao login -method=userpass username=ross" first.
    #
    # OpenSSH reads a certificate that sits next to its key and carries the
    # "-cert.pub" ending, with no configuration at all, so this writes there and
    # nothing else has to change.
    environment.systemPackages = [
      (pkgs.writeShellApplication {
        name = "argama-ssh-cert";
        runtimeInputs = [
          pkgs.openssh
          pkgs.curl
          pkgs.jq
        ];
        text = ''
          key="''${1:-$HOME/.ssh/id_ed25519}"
          addr="''${BAO_ADDR:-https://vault.argama.nix}"

          if [ -z "''${BAO_TOKEN:-}" ]; then
            if [ -r "$HOME/.vault-token" ]; then
              BAO_TOKEN=$(cat "$HOME/.vault-token")
            else
              echo "No token. Run: bao login -method=userpass username=ross" >&2
              exit 1
            fi
          fi

          if [ ! -f "$key" ]; then
            echo "Making a new key at $key"
            ssh-keygen -t ed25519 -N "" -f "$key"
          fi

          jq -n --arg pk "$(cat "$key.pub")" '{public_key:$pk}' \
            | curl -sS --fail-with-body \
                -H "X-Vault-Token: $BAO_TOKEN" \
                -X POST --data @- \
                "$addr/v1/ssh-client-signer/sign/ross" \
            | jq -r '.data.signed_key' > "$key-cert.pub"

          echo "Wrote $key-cert.pub"
          ssh-keygen -L -f "$key-cert.pub" | grep -E 'Valid|Principals' -A 1
        '';
      })
    ];

    # The certificate goes below /var/lib and never below /run. It is a public
    # document, so there is nothing to protect, and sshd refuses to start when
    # HostCertificate names a file that is missing. A certificate in /run
    # disappears at every boot, and the unit that writes it cannot run until
    # OpenBao is unsealed, which needs the SSH that sshd is no longer giving.
    services.openssh.settings.HostCertificate = lib.mkIf config.ross.sshCa.hostCert "/var/lib/ssh-host-cert/ssh_host_ed25519_key-cert.pub";

    systemd.services = lib.mkMerge [
      {
        ssh-host-cert = lib.mkIf config.ross.sshCa.hostCert {
          description = "Renew this machine's SSH host certificate from argama";
          # Daily against a certificate that lives 30 days. So OpenBao can stay
          # sealed for a month before any client refuses this host.
          startAt = "daily";
          wantedBy = [ "multi-user.target" ];
          path = [
            pkgs.curl
            pkgs.jq
            pkgs.openssh
            pkgs.coreutils
            pkgs.gnused
            pkgs.findutils
          ];
          serviceConfig = {
            Type = "oneshot";
            StateDirectory = "ssh-host-cert";
            StateDirectoryMode = "0755";
            # OpenBao is sealed at every boot. Keep trying rather than giving up,
            # the same as the agent sidecars in devices/argama/secrets.nix.
            Restart = "on-failure";
            RestartSec = "5m";
          };
          unitConfig.StartLimitIntervalSec = 0;
          script = ''
            addr="https://vault.argama.nix"
            out=/var/lib/ssh-host-cert/ssh_host_ed25519_key-cert.pub

            token=$(jq -n \
                --arg r "$(cat /var/lib/vault-agent/role-id)" \
                --arg s "$(cat /var/lib/vault-agent/secret-id)" \
                '{role_id:$r, secret_id:$s}' \
              | curl -sS --fail-with-body -X POST --data @- \
                  "$addr/v1/auth/approle/login" \
              | jq -r '.auth.client_token')

            jq -n \
                --arg pk "$(cat /etc/ssh/ssh_host_ed25519_key.pub)" \
                --arg pr "${lib.concatStringsSep "," config.ross.sshCa.hostPrincipals}" \
                '{public_key:$pk, cert_type:"host", valid_principals:$pr}' \
              | curl -sS --fail-with-body \
                  -H "X-Vault-Token: $token" \
                  -X POST --data @- \
                  "$addr/v1/ssh-host-signer/sign/host" \
              | jq -r '.data.signed_key' > "$out.new"

            # Check the new file before it replaces the working one. A truncated or
            # empty answer would stop sshd at its next start.
            ssh-keygen -L -f "$out.new" > /dev/null
            mv "$out.new" "$out"

            # node_exporter reads this directory, so the end of the certificate
            # becomes a series that Grafana can watch. An expired host
            # certificate takes this machine away from every client at once,
            # and nothing else here would show it coming.
            install -d -m 0755 /var/lib/node_exporter/textfile
            notAfter=$(ssh-keygen -L -f "$out" \
              | sed -n 's/.*Valid: from .* to \(.*\)$/\1/p' \
              | xargs -I{} date -d {} +%s)
            printf '# HELP ssh_host_cert_not_after Seconds since the epoch when this host certificate ends.\n# TYPE ssh_host_cert_not_after gauge\nssh_host_cert_not_after %s\n' \
              "$notAfter" > /var/lib/node_exporter/textfile/ssh_host_cert.prom.new
            mv /var/lib/node_exporter/textfile/ssh_host_cert.prom.new \
              /var/lib/node_exporter/textfile/ssh_host_cert.prom

            systemctl try-reload-or-restart sshd.service
          '';
        };
      }

      # One unit for each role this machine needs. A service account cannot log
      # in to OpenBao by hand, so it uses the AppRole the machine already holds
      # for restic.
      (lib.listToAttrs (
        map (
          role:
          lib.nameValuePair "ssh-client-cert-${role}" {
            description = "Renew the ${role} SSH client certificate from argama";
            startAt = "daily";
            wantedBy = [ "multi-user.target" ];
            path = [
              pkgs.curl
              pkgs.jq
              pkgs.openssh
            ];
            serviceConfig = {
              Type = "oneshot";
              StateDirectory = "ssh-client-cert";
              StateDirectoryMode = "0700";
              Restart = "on-failure";
              RestartSec = "5m";
            };
            unitConfig.StartLimitIntervalSec = 0;
            script = ''
              addr="https://vault.argama.nix"
              key=/var/lib/ssh-client-cert/${role}

              # The private key is made once and never leaves this machine. Only
              # the certificate is renewed, so nothing secret travels.
              if [ ! -f "$key" ]; then
                ssh-keygen -t ed25519 -N "" -f "$key" -C "${role}@${config.networking.hostName}"
              fi

              token=$(jq -n \
                  --arg r "$(cat /var/lib/vault-agent/role-id)" \
                  --arg s "$(cat /var/lib/vault-agent/secret-id)" \
                  '{role_id:$r, secret_id:$s}' \
                | curl -sS --fail-with-body -X POST --data @- \
                    "$addr/v1/auth/approle/login" \
                | jq -r '.auth.client_token')

              jq -n --arg pk "$(cat "$key.pub")" '{public_key:$pk}' \
                | curl -sS --fail-with-body \
                    -H "X-Vault-Token: $token" \
                    -X POST --data @- \
                    "$addr/v1/ssh-client-signer/sign/${role}" \
                | jq -r '.data.signed_key' > "$key-cert.pub.new"

              ssh-keygen -L -f "$key-cert.pub.new" > /dev/null
              mv "$key-cert.pub.new" "$key-cert.pub"
            '';
          }
        ) config.ross.sshCa.clientCerts
      ))
    ];

    warnings = lib.optional (!userPresent && !hostPresent) ''
      certs/ssh-user-ca.pub and certs/ssh-host-ca.pub are missing, so this
      machine trusts no SSH certificate. Logins fall back to authorized_keys and
      every host stays unknown on a first connection. See modules/ssh-ca.nix.
    '';
  };
}
