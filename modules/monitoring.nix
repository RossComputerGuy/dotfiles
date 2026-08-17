{
  config,
  lib,
  ...
}:
let
  cfg = config.ross.monitoring;
in
{
  options.ross.monitoring = {
    enable = lib.mkEnableOption ''
      a node exporter that argama scrapes.

      This machine then appears on the Grafana dashboards next to argama. It
      says nothing about the machine that argama cannot already reach, because
      the exporter answers on the tailnet alone'';

    port = lib.mkOption {
      description = ''
        Where the node exporter answers. argama names this port in its scrape
        configuration, so a machine that changes it drops off the dashboards.
      '';
      type = lib.types.port;
      default = 9100;
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus.exporters.node = {
      enable = true;
      inherit (cfg) port;
      # Answer on every address, then let the firewall decide. The rule below
      # opens the port on the tailnet and nowhere else, which is the same shape
      # radicle.nix uses for its gossip port.
      #
      # The loopback alone would not do, because argama scrapes across the
      # tailnet and a laptop has no fixed address to bind to.
      listenAddress = "0.0.0.0";
      enabledCollectors = [
        # Which units failed. This is the one that turns a quiet broken timer
        # into something a dashboard can show.
        "systemd"
        "processes"
        # modules/ssh-ca.nix writes the end of this machine's host certificate
        # here, when it has one. An expired host certificate takes a machine
        # away from every client at once.
        "textfile"
      ];
      extraFlags = [
        "--collector.textfile.directory=/var/lib/node_exporter/textfile"
      ];
    };

    # The collector complains at every scrape when its directory is absent, and
    # a machine with no host certificate never makes it.
    systemd.tmpfiles.rules = [
      "d /var/lib/node_exporter 0755 root root -"
      "d /var/lib/node_exporter/textfile 0755 root root -"
    ];

    networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ cfg.port ];
  };
}
