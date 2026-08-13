{
  config,
  lib,
  ...
}:
let
  ports = import ./service-ports.nix;
  agent = config.detsys.vaultAgent.systemd.services.caddy;

  # One file holds the certificate, its chain and the key. It has to be one
  # file, because each render of a PKI template issues a fresh certificate, so
  # a separate key template would hold the key of a different certificate.
  # Caddy reads the certificate blocks from the first path and the key block
  # from the second, so the same path works for both.
  certFile = agent.secretFiles.files."argama.pem".path;

  tlsNames = map (n: "${n}.argama.nix") (builtins.attrNames ports.tls);
  altNames = builtins.concatStringsSep "," ([ "argama.nix" ] ++ tlsNames);

  # Authelia answers this for every guarded name. Caddy asks it first and only
  # passes the request on when it says yes, so one login covers them all.
  forwardAuth = ''
    forward_auth 127.0.0.1:${toString ports.tls.auth.port} {
      uri /api/authz/forward-auth
      copy_headers Remote-User Remote-Groups Remote-Name Remote-Email
    }
  '';

  guard = svc: lib.optionalString (svc.auth == "forward") forwardAuth;

  tlsHosts = lib.mapAttrs' (
    name: svc:
    lib.nameValuePair "${name}.argama.nix" {
      extraConfig = ''
        tls ${certFile} ${certFile}
        ${guard svc}
        reverse_proxy 127.0.0.1:${toString svc.port}
      '';
    }
  ) ports.tls;

  # The http:// prefix stops Caddy from asking for a certificate for these.
  plainHosts = lib.mapAttrs' (
    name: svc:
    lib.nameValuePair "http://${name}.argama.nix" {
      extraConfig = ''
        ${guard svc}
        reverse_proxy 127.0.0.1:${toString svc.port}
      '';
    }
  ) ports.plain;
in
{
  # The certificate comes from OpenBao's PKI, and that PKI is an intermediate
  # signed by a root whose private key never leaves the YubiKey. So argama can
  # issue for its own zone every day, and the root only comes out when the
  # intermediate needs signing again.
  #
  # The clients trust that root. modules/backup.nix reads it from
  # secret/argama/ca and hands it to restic as RESTIC_CACERT.
  detsys.vaultAgent.systemd.services.caddy = {
    enable = true;
    secretFiles.files."argama.pem" = {
      # A fresh certificate means Caddy has to load it.
      changeAction = "restart";
      perms = "0400";
      template = ''
        {{ with secret "pki/issue/argama" "common_name=argama.nix" "alt_names=${altNames}" "ttl=720h" }}{{ .Data.certificate }}
        {{ .Data.issuing_ca }}
        {{ .Data.private_key }}{{ end }}
      '';
    };
  };

  services.caddy = {
    enable = true;
    virtualHosts = tlsHosts // plainHosts;
  };

  # Caddy cannot get a certificate until OpenBao is unsealed, and the YubiKey is
  # a daily carry, so it is not there at boot. Let the sidecar wait instead of
  # giving up.
  systemd.services.detsys-vaultAgent-caddy = {
    after = [ "openbao.service" ];
    wants = [ "openbao.service" ];
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig = {
      Restart = "always";
      RestartSec = 15;
    };
  };

  # Caddy is the only way to every service, so no service opens a port of its
  # own. 80 and 443 are open on the LAN as well as the tailnet, because a
  # machine at home reaches argama by its LAN address. See dns.nix.
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # The one exception. A client's agent reads argama's certificate authority
  # from OpenBao, so it cannot check a certificate signed by that authority
  # until after it has read it. Trust has to start somewhere, and Tailscale
  # encrypts the link. This port is open on the tailnet only, in secrets.nix.
}
