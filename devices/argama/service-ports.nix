# One list of the services argama publishes, so the zone in dns.nix, the virtual
# hosts in web.nix and the names on the certificate cannot drift apart.
#
# Each name below answers at <name>.argama.nix.
#
# auth says how Caddy guards the name:
#   "forward"  Authelia checks every request first. One login covers them all.
#   "none"     The service does its own checking. Each one below says why.
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
    qbit = {
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
