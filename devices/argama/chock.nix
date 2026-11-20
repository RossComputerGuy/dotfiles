{ inputs, ... }:
{
  services.chock-daemon = {
    enable = true;
    oidcProvider = "authelia";
    oidcIssuer = "https://auth.argama.nix";
    oidcClientId = "chock";
    web = {
      enable = true;
      externalUrl = "https://chock.argama.nix";
      socketGroup = "caddy";
    };
  };

  # The exact Authelia subject is the only identity that bootstraps an admin.
  detsys.vaultAgent.systemd.services.chock-daemon = {
    enable = true;
    environment = {
      changeAction = "restart";
      template = ''
        CHOCK_OIDC_ADMIN_SUBJECT={{ with secret "secret/data/argama/chock" }}{{ .Data.data.admin_subject }}{{ end }}
      '';
    };
  };
  systemd.services.detsys-vaultAgent-chock-daemon.upholds = [ "chock-daemon.service" ];
}
