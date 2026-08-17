{
  config,
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages = [ pkgs.smartmontools ];

  # The textfile collector below complains at every scrape when its directory is
  # absent, and nothing makes it until ross.sshCa.hostCert is on. Make it here,
  # so the collector stays quiet while it has nothing to read.
  systemd.tmpfiles.rules = [
    "d /var/lib/node_exporter 0755 root root -"
    "d /var/lib/node_exporter/textfile 0755 root root -"
  ];

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
          # ssh-host-cert.service writes the end of this machine's host
          # certificate here. An expired one takes this machine away from every
          # client at once, because a client that holds a cert-authority line
          # refuses an expired host certificate and does not fall back to the
          # plain host key. See modules/ssh-ca.nix.
          "textfile"
        ];
        extraFlags = [
          "--collector.textfile.directory=/var/lib/node_exporter/textfile"
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
      # The exporter carries its own copy of smartctl and puts none on the
      # PATH, so an operator looking at a faulted disk cannot ask it anything.
      # A dashboard says which disk, and this says why.
    };

    # One job for each kind of exporter, and an instance label that is a machine
    # name rather than an address. Prometheus only fills instance in from the
    # address when the target has not set it, so these win, and a dashboard can
    # then group by instance and read as a list of machines.
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = [ "127.0.0.1:9100" ];
            labels.instance = "argama";
          }
          # The rest of the fleet, over the tailnet. modules/monitoring.nix is
          # the other half. hizack-b is a laptop, so it reads as down whenever
          # it is away, which is the truth and not a fault.
          {
            targets = [ "zeta3a:9100" ];
            labels.instance = "zeta3a";
          }
          {
            targets = [ "hizack-b:9100" ];
            labels.instance = "hizack-b";
          }
        ];
      }
      {
        job_name = "zfs";
        static_configs = [
          {
            targets = [ "127.0.0.1:9134" ];
            labels.instance = "argama";
          }
        ];
      }
      {
        job_name = "smartctl";
        static_configs = [
          {
            targets = [ "127.0.0.1:9633" ];
            labels.instance = "argama";
          }
        ];
      }
      {
        # Both resolvers, the LAN side and the tailnet side. See dns.nix.
        job_name = "blocky";
        static_configs = [
          {
            targets = [ "127.0.0.1:4000" ];
            labels.instance = "lan";
          }
          {
            targets = [ "127.0.0.1:4001" ];
            labels.instance = "tailnet";
          }
        ];
      }
      {
        job_name = "restic";
        static_configs = [
          {
            targets = [ "127.0.0.1:8000" ];
            labels.instance = "argama";
          }
        ];
      }
      {
        # Prometheus watching itself. A scrape that starts failing everywhere at
        # once is usually Prometheus and not the targets.
        job_name = "prometheus";
        static_configs = [
          {
            targets = [ "127.0.0.1:9090" ];
            labels.instance = "argama";
          }
        ];
      }
      {
        # The web server in front of every name in the zone. See web.nix, which
        # turns the per request counters on. This is the admin endpoint and it
        # answers on the loopback alone.
        job_name = "caddy";
        static_configs = [
          {
            targets = [ "127.0.0.1:2019" ];
            labels.instance = "argama";
          }
        ];
      }
      {
        # git.nix turns this on. The port is the loopback one Caddy proxies to.
        job_name = "forgejo";
        static_configs = [
          {
            targets = [ "127.0.0.1:3001" ];
            labels.instance = "argama";
          }
        ];
      }
      {
        # Hydra serves Prometheus text on its own web port with no option to
        # set. It counts requests to itself and no builds, so treat this as a
        # sign of life rather than a picture of the queue.
        job_name = "hydra";
        static_configs = [
          {
            targets = [ "127.0.0.1:3000" ];
            labels.instance = "argama";
          }
        ];
      }
      {
        # The metrics listener from secrets.nix, not the one the fleet uses.
        # OpenBao answers here without a token, which is why this address
        # leaves the machine by no route.
        job_name = "openbao";
        metrics_path = "/v1/sys/metrics";
        params.format = [ "prometheus" ];
        static_configs = [
          {
            targets = [ "127.0.0.1:8202" ];
            labels.instance = "argama";
          }
        ];
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

  # Grafana has BindsTo on the sidecar, so a sealed OpenBao stops the sidecar
  # and takes Grafana with it. Nothing would start Grafana again, because
  # BindsTo only carries the stop and multi-user.target has long since been
  # reached. OpenBao seals at every boot, so without this the dashboards stay
  # down after every restart until an operator notices. Authelia, Vaultwarden
  # and paperless carry the same line for the same reason.
  systemd.services.detsys-vaultAgent-grafana.upholds = [ "grafana.service" ];

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
    # Remove it, then make it again. Grafana invented an identifier for this
    # datasource the first time it started, and provisioning cannot move an
    # existing datasource onto a different one. It stops with "Datasource
    # provisioning error: data source not found" and the whole service fails to
    # start. Deleting first runs before the list below, so the datasource comes
    # back with the identifier the dashboards name.
    #
    # This is safe to keep. On a machine that has never run Grafana it removes
    # nothing, and on this one it removes only what the next lines put back.
    provision.datasources.settings = {
      deleteDatasources = [
        {
          name = "Prometheus";
          orgId = 1;
        }
      ];

      datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://127.0.0.1:9090";
          isDefault = true;
          # Fixed on purpose. Every dashboard in dashboards.nix names the
          # datasource by this identifier, and Grafana would otherwise invent
          # one at first start, which a dashboard written ahead of time cannot
          # name.
          uid = "prometheus";
        }
      ];
    };
  };

  # No port is open here. Caddy publishes both as names. See web.nix.
}
