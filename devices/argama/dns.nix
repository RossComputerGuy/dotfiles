{
  config,
  lib,
  pkgs,
  ...
}:
let
  # argama answers its own zone with a different address on each side, so a LAN
  # client takes the LAN path and a client away from home takes the tailnet.
  #
  # blocky binds these, not only answers with them. An address that is not on
  # the machine fails the bind, and the unit then dies and takes the loopback
  # listener with it, so nothing on argama resolves either.
  #
  # The LAN address arrives by DHCP. Reserve it for this MAC on the router
  # (48:21:0b:79:5b:5f, enP3p3s0f1), because a machine that serves DNS to the
  # house must not change address when a lease moves.
  lanAddress = "192.168.1.163";
  tailnetAddress = "100.94.55.6";

  ports = import ./service-ports.nix;

  # The names argama answers for. Each one points at argama itself, so the whole
  # zone is one address per side. The list comes from service-ports.nix, so a
  # new service cannot get a virtual host without also getting a name.
  zoneNames = [
    "argama.nix"
  ]
  ++ map (n: "${n}.argama.nix") (builtins.attrNames ports.tls ++ builtins.attrNames ports.plain);

  mappingFor = address: lib.listToAttrs (map (n: lib.nameValuePair n address) zoneNames);

  # blocky has no per-client answers, so split horizon needs one instance for
  # each side. Everything except the listen address and the zone answer is the
  # same, so both instances come from this function.
  blockySettings = dnsBind: httpBind: address: {
    ports = {
      dns = dnsBind;
      # Caddy publishes the LAN instance as dns.argama.nix, and Prometheus
      # scrapes both, so each web interface binds the loopback.
      http = httpBind;
      # Bind an address before it is on an interface. Both instances need it:
      # the LAN address arrives by DHCP, and the tailnet address arrives when
      # Tailscale comes up. Neither is there when blocky starts, and a plain
      # bind then fails with "cannot assign requested address".
      freeBind = true;
    };
    upstreams.groups.default = [ "127.0.0.1:5335" ];
    # blocky downloads the lists over HTTPS, and that download needs a resolver
    # which is not blocky itself.
    bootstrapDns = [ { upstream = "127.0.0.1:5335"; } ];
    customDNS.mapping = mappingFor address;
    blocking = {
      denylists.ads = [
        "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
      ];
      clientGroupsBlock.default = [ "ads" ];
    };
    caching = {
      minTime = "5m";
      prefetching = true;
    };
    prometheus.enable = true;
  };

  yaml = pkgs.formats.yaml { };
  tailnetConfig = yaml.generate "blocky-tailnet.yaml" (
    blockySettings "${tailnetAddress}:53" "127.0.0.1:4001" tailnetAddress
  );
in
{
  # unbound does the recursion itself. It asks the root servers and follows the
  # chain down, so no upstream resolver sees the queries. It listens on the
  # loopback only, and the two blocky instances are its clients.
  services.unbound = {
    enable = true;
    # blocky owns port 53 and the resolver entry, so unbound must not take them.
    resolveLocalQueries = false;
    settings.server = {
      interface = [ "127.0.0.1" ];
      port = 5335;
      access-control = [ "127.0.0.0/8 allow" ];
      harden-glue = true;
      harden-dnssec-stripped = true;
      prefetch = true;
    };
  };

  # The LAN side. It answers on the loopback too, so argama resolves its own
  # names without going out to itself over the network.
  services.blocky = {
    enable = true;
    settings = blockySettings "127.0.0.1:53,${lanAddress}:53" "127.0.0.1:4000" lanAddress;
  };

  # The nixpkgs module gives blocky "Wants=network-online.target" and no
  # matching After=. Wants pulls the target in but does not wait for it, so
  # blocky starts before DHCP has put the address on the interface and the bind
  # to the LAN address fails.
  #
  # Its Restart=on-failure then retries at the 100ms default, which spends
  # systemd's five attempts in under a second and leaves the unit dead for
  # good. Wait for the address, and retry slowly enough to be useful.
  systemd.services.blocky = {
    after = [
      "network-online.target"
      "unbound.service"
    ];
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig.RestartSec = 5;
  };

  # The tailnet side. The NixOS module holds one instance only, so the second
  # one is a plain unit with a generated configuration.
  systemd.services.blocky-tailnet = {
    description = "blocky DNS for the tailnet side of argama.nix";
    after = [
      "network-online.target"
      "unbound.service"
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      DynamicUser = true;
      StateDirectory = "blocky-tailnet";
      ExecStart = "${lib.getExe pkgs.blocky} --config ${tailnetConfig}";
      Restart = "on-failure";
      RestartSec = 5;
      # Binding port 53 needs this, and DynamicUser drops everything else.
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
    };
  };

  # argama runs the resolver for the house, so it must use it as well. Without
  # this, systemd-resolved sends every query to whatever address DHCP gave it,
  # the router has never heard of the .nix zone, and argama cannot reach its own
  # services by name even while blocky answers the rest of the house correctly.
  #
  # resolved stays on. Tailscale gives it the route for the tailnet names, and
  # turning resolved off would take that away with it.
  #
  # "~." makes resolved send everything to the servers below instead of the ones
  # DHCP puts on the link. Without it the per link servers win and the setting
  # above does nothing. Tailscale registers its own domain, which is more exact
  # than "~.", so the tailnet names still take the Tailscale path.
  networking.nameservers = [ "127.0.0.1" ];
  services.resolved.settings.Resolve.Domains = [ "~." ];

  # argama answers DNS for the whole house, so port 53 is open on every
  # interface. If this machine ever gets a public address, change these two
  # lines to networking.firewall.interfaces.<lan>.allowed*Ports, or it becomes
  # an open resolver that a stranger can use for an amplification attack.
  networking.firewall = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 ];
  };
}
