# One list of the services argama publishes, so the zone in dns.nix, the virtual
# hosts in web.nix and the names on the certificate cannot drift apart.
#
# Each name below answers at <name>.argama.nix.
#
# auth says how Caddy guards the name:
#   "forward"  Authelia checks every request first. One login covers them all.
#   "none"     The service does its own checking. Each one below says why.
#
# host is where Caddy sends the request. It is 127.0.0.1 unless a service says
# otherwise, and only a service in another network namespace says otherwise.
{
  # Reached over TLS on 443. Caddy passes each one to its port on the loopback.
  tls = {
    # Authelia itself. It cannot sit behind its own check.
    auth = {
      port = 9091;
      auth = "none";
    };

    # Jellyfin keeps its own login. A forward check works by sending a browser
    # to a login page, and a television, a phone application or a Chromecast
    # cannot follow that. Guarding it here would break every client that is not
    # a browser.
    jellyfin = {
      port = 8096;
      auth = "none";
    };

    # restic speaks HTTP basic authentication and follows no redirect.
    backup = {
      port = 8000;
      auth = "none";
    };

    # Vaultwarden, the password manager for people. The Bitwarden browser
    # extension and the phone applications talk to an API and follow no login
    # page, so a forward check would break every client that is not a browser
    # tab. That is the same reason Jellyfin carries none. Its own account and
    # second factor are the boundary.
    pass = {
      port = 8222;
      auth = "none";
    };

    # OpenBao has its own tokens, and it is where Authelia's own secrets come
    # from, so it must answer before Authelia starts.
    vault = {
      port = 8200;
      auth = "none";
    };

    seerr = {
      port = 5055;
      auth = "forward";
    };
    sonarr = {
      port = 8989;
      auth = "forward";
    };
    radarr = {
      port = 7878;
      auth = "forward";
    };
    prowlarr = {
      port = 9696;
      auth = "forward";
    };
    # qBittorrent runs inside the mullvad network namespace, so it does not
    # listen on argama's loopback at all. vpnNamespaces.mullvad.portMappings
    # writes a DNAT rule, but only into PREROUTING, which sees traffic that
    # arrives from another machine. Caddy runs on this machine, so its packets
    # take OUTPUT instead and never meet that rule. Give Caddy the address in
    # the namespace and no rule is needed.
    qbit = {
      host = "192.168.15.1";
      port = 8080;
      auth = "forward";
    };
    hydra = {
      port = 3000;
      auth = "forward";
    };
    git = {
      port = 3001;
      auth = "forward";
    };

    # radicle-httpd is read only. It serves the browsing API and a git clone
    # over HTTP, and git follows no login redirect, so a forward check would
    # only break the clone. That is the same reason the binary cache and restic
    # carry none. A write goes to the node on 8776 instead, which checks a
    # signature and never sees this port. Hydra reads its jobsets from here.
    radicle = {
      port = 8081;
      auth = "none";
    };
    grafana = {
      port = 3002;
      auth = "forward";
    };
    prometheus = {
      port = 9090;
      auth = "forward";
    };
    paperless = {
      port = 28981;
      auth = "forward";
    };
    dns = {
      port = 4000;
      auth = "forward";
    };
  };

  # Reached over plain HTTP on 80.
  #
  # The binary cache cannot use TLS. The Nix daemon needs a certificate
  # authority in its trust store before it starts, and OpenBao gives argama's
  # authority to a machine long after that. It does not need TLS either: every
  # store path carries a signature, and a client checks that signature against
  # the public key in trusted-public-keys. A changed byte on the wire fails that
  # check, so the transport carries no trust. The Nix daemon follows no login
  # redirect either, so it takes no forward check.
  plain = {
    cache = {
      port = 5000;
      auth = "none";
    };
  };
}
