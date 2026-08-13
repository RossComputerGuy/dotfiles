{
  config,
  lib,
  ...
}:
{
  services.prometheus = {
    enable = true;
    port = 9090;
    # Caddy is the only way in, so bind the loopback.
    listenAddress = "127.0.0.1";
    globalConfig.scrape_interval = "30s";

    exporters = {
      node = {
        enable = true;
        port = 9100;
        listenAddress = "127.0.0.1";
        enabledCollectors = [
          "systemd"
          "processes"
        ];
      };
      # The pools hold the media, the backups and the OpenBao data, so their
      # health is the first thing to watch.
      zfs = {
        enable = true;
        port = 9134;
        listenAddress = "127.0.0.1";
      };
      smartctl = {
        enable = true;
        port = 9633;
        listenAddress = "127.0.0.1";
      };
    };

    scrapeConfigs = [
      {
        job_name = "argama";
        static_configs = [
          {
            targets = [
              "127.0.0.1:9100"
              "127.0.0.1:9134"
              "127.0.0.1:9633"
            ];
          }
        ];
      }
      {
        # Both resolvers, the LAN side and the tailnet side. See dns.nix.
        job_name = "blocky";
        static_configs = [
          {
            targets = [
              "127.0.0.1:4000"
              "127.0.0.1:4001"
            ];
          }
        ];
      }
      {
        job_name = "restic";
        static_configs = [ { targets = [ "127.0.0.1:8000" ]; } ];
      }
    ];
  };

  # Grafana encrypts the secrets in its database with this key, and it reads the
  # file itself at run time. That is a plain read inside its own namespace, not
  # a LoadCredential=, so the agent can supply it directly.
  #
  #   bao kv put secret/argama/grafana secret_key=$(head -c 32 /dev/urandom | base64)
  detsys.vaultAgent.systemd.services.grafana = {
    enable = true;
    secretFiles.files."secret-key" = {
      changeAction = "restart";
      template = ''
        {{ with secret "secret/data/argama/grafana" }}{{ .Data.data.secret_key }}{{ end }}
      '';
    };
  };

  services.grafana = {
    enable = true;
    settings.security.secret_key = "$__file{${
      config.detsys.vaultAgent.systemd.services.grafana.secretFiles.files."secret-key".path
    }}";
    settings.server = {
      # Caddy is the only way in, so bind the loopback.
      http_addr = "127.0.0.1";
      http_port = 3002;
      root_url = "https://grafana.argama.nix/";
    };
    provision.datasources.settings.datasources = [
      {
        name = "Prometheus";
        type = "prometheus";
        url = "http://127.0.0.1:9090";
        isDefault = true;
      }
    ];
  };

  # No port is open here. Caddy publishes both as names. See web.nix.
}
