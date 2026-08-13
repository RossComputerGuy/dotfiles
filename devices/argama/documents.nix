{
  config,
  lib,
  ...
}:
{
  services.paperless = {
    enable = true;
    # Caddy is the only way in, so bind the loopback.
    address = "127.0.0.1";
    port = 28981;
    # passwordFile stays unset on purpose. It becomes a LoadCredential=, which
    # systemd resolves before the unit joins the agent's namespace. paperless
    # also accepts PAPERLESS_ADMIN_PASSWORD from the environment, and the agent
    # writes its environment files to /run, which is not namespaced. So the
    # password comes from OpenBao through the environment instead.
    settings = {
      PAPERLESS_URL = "https://paperless.argama.nix";
      PAPERLESS_OCR_LANGUAGE = "eng";
      # 64 cores. Let the OCR use a real share of them.
      PAPERLESS_TASK_WORKERS = 8;
      PAPERLESS_THREADS_PER_WORKER = 4;
    };
  };

  # The scheduler unit is the one that makes the superuser on start.
  #
  #   bao kv put secret/argama/paperless admin_password=<password>
  detsys.vaultAgent.systemd.services.paperless-scheduler = {
    enable = true;
    environment = {
      changeAction = "restart";
      template = ''
        PAPERLESS_ADMIN_PASSWORD={{ with secret "secret/data/argama/paperless" }}{{ .Data.data.admin_password }}{{ end }}
      '';
    };
  };

  # No port is open here. Caddy publishes paperless.argama.nix. See web.nix.
}
