{
  config,
  lib,
  pkgs,
  ...
}:
{
  # The agent sidecar from nixos-vault-service runs pkgs.vault, which has the
  # BUSL license. OpenBao is the MPL fork, it speaks the same API, and its
  # binary is called bao. Give the sidecar a "vault" binary that is OpenBao, so
  # no BUSL binary stays on the machine.
  nixpkgs.overlays = [
    (final: prev: {
      vault =
        final.runCommand "openbao-as-vault-${final.openbao.version}"
          {
            meta = final.openbao.meta // {
              mainProgram = "vault";
            };
          }
          ''
            mkdir -p $out/bin
            ln -s ${final.lib.getExe final.openbao} $out/bin/vault
          '';
    })
  ];

  # argama is the secret server for the fleet. Its own boot secrets stay on
  # disk, because it cannot read a secret before it has started OpenBao.
  services.openbao = {
    enable = true;
    settings = {
      ui = true;
      listener.default = {
        type = "tcp";
        address = "0.0.0.0:8200";
        # Tailscale encrypts every link between the machines and this listener
        # is open on the tailnet only, so a certificate adds work and no
        # protection.
        tls_disable = true;
      };
      # Raft, not the file backend. Raft can auto unseal against a PKCS#11
      # token, and the package has HSM support built in. See the README for the
      # seal stanza to add once the TPM token exists.
      storage.raft = {
        path = "/var/lib/openbao";
        node_id = "argama";
      };
      api_addr = "http://argama:8200";
      cluster_addr = "http://127.0.0.1:8201";
    };
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 8200 ];

  # Defaults for each systemd service that opts in with
  # detsys.vaultAgent.systemd.services.<name>.enable.
  detsys.vaultAgent.defaultAgentConfig = {
    vault.address = "http://127.0.0.1:8200";
    auto_auth = {
      method = [
        {
          type = "approle";
          config = {
            role_id_file_path = "/var/lib/vault-agent/role-id";
            secret_id_file_path = "/var/lib/vault-agent/secret-id";
            # The agent reads this file again after a restart, so it must stay.
            remove_secret_id_file_after_reading = false;
          };
        }
      ];
    };
  };

  # The Mullvad WireGuard configuration comes from OpenBao. The agent writes it
  # into the PrivateTmp of the mullvad unit, and media.nix points
  # vpnNamespaces.mullvad.wireguardConfigFile at that path.
  #
  # Put the secret in OpenBao with:
  #   bao kv put secret/argama/mullvad config=@wg0.conf
  detsys.vaultAgent.systemd.services.mullvad = {
    enable = true;
    secretFiles.files."wireguard.conf" = {
      # A new configuration means a new tunnel, so the namespace must go down
      # and come up again.
      changeAction = "restart";
      template = ''
        {{ with secret "secret/data/argama/mullvad" }}{{ .Data.data.config }}{{ end }}
      '';
    };
  };

  # harmonia reads its signing key with LoadCredential=, and systemd resolves a
  # credential before the unit joins the agent's namespace. The agent writes
  # secret files into PrivateTmp, which only covers /tmp and /var/tmp, so /run
  # stays shared with the host. This unit does join the namespace, so it can
  # copy the key out to /run, where LoadCredential finds it.
  #
  #   bao kv put secret/argama/harmonia signing_key=@harmonia.secret
  detsys.vaultAgent.systemd.services.harmonia-key = {
    enable = true;
    secretFiles.files."cache.secret" = {
      changeAction = "restart";
      template = ''
        {{ with secret "secret/data/argama/harmonia" }}{{ .Data.data.signing_key }}{{ end }}
      '';
    };
  };

  systemd.services = {
    harmonia-key = {
      description = "Publish the harmonia signing key where LoadCredential can read it";
      requiredBy = [ "harmonia.service" ];
      before = [ "harmonia.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "harmonia-key";
        RuntimeDirectoryMode = "0700";
        # Keep the directory across a restart of this unit, so harmonia never
        # finds the key missing while the key is written again.
        RuntimeDirectoryPreserve = "yes";
        ExecStart = pkgs.writeShellScript "harmonia-key-publish" ''
          ${lib.getExe' pkgs.coreutils "install"} -m 0400 \
            ${config.detsys.vaultAgent.systemd.services.harmonia-key.secretFiles.files."cache.secret".path} \
            /run/harmonia-key/cache.secret
        '';
      };
    };

    # A new key means harmonia must load it again.
    harmonia = {
      after = [ "harmonia-key.service" ];
      bindsTo = [ "harmonia-key.service" ];
    };
  }
  # Until an operator unseals OpenBao, the agent cannot read anything. Let the
  # sidecars retry for as long as it takes, so the tunnel and the cache come up
  # by themselves after the unseal instead of waiting for a manual start.
  //
    lib.genAttrs
      [
        "detsys-vaultAgent-mullvad"
        "detsys-vaultAgent-harmonia-key"
        "detsys-vaultAgent-paperless-scheduler"
        "detsys-vaultAgent-grafana"
        "detsys-vaultAgent-radicle-key"
      ]
      (_: {
        after = [ "openbao.service" ];
        wants = [ "openbao.service" ];
        unitConfig.StartLimitIntervalSec = 0;
        serviceConfig = {
          Restart = "always";
          RestartSec = 15;
        };
      });
}
