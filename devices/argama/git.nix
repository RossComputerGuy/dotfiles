{
  config,
  lib,
  ...
}:
{
  services.forgejo = {
    enable = true;
    lfs.enable = true;
    database.type = "postgres";
    settings = {
      DEFAULT.APP_NAME = "Argama";
      server = {
        DOMAIN = "git.argama.nix";
        # Caddy is the only way in, so bind the loopback.
        HTTP_ADDR = "127.0.0.1";
        # Hydra holds 3000.
        HTTP_PORT = 3001;
        ROOT_URL = "https://git.argama.nix/";
      };
      # This instance is for one person on a private tailnet.
      service.DISABLE_REGISTRATION = true;
      # Lets a repository pull from GitHub on a timer, so the code stays here
      # if GitHub goes away.
      mirror.ENABLED = true;
      # Answers at /metrics on the port above, which is the loopback, so
      # Prometheus reaches it and nothing else does. A TOKEN here would add a
      # bearer check, and it would guard a path that only this machine can ask
      # for. See monitoring.nix for the scrape.
      metrics.ENABLED = true;
    };
  };

  # Registration is off, so the first account cannot come from the web
  # interface. It comes from the command below, which needs the forgejo command
  # on the PATH. The module does not put it there.
  #
  #   sudo -u forgejo env \
  #     FORGEJO_WORK_DIR=/var/lib/forgejo \
  #     FORGEJO_CUSTOM=/var/lib/forgejo/custom \
  #     forgejo admin user create --admin \
  #       --username ross --email you@example.com --random-password
  #
  # The environment must be given. forgejo reads its configuration from the
  # work directory, and a shell has neither variable, so it would make a new
  # empty instance in the current directory instead of opening this one.
  environment.systemPackages = [ config.services.forgejo.package ];

  # Hydra reads a jobset from a flake URL, so it can build straight from
  # Forgejo. Add the jobset in the Hydra web interface with a flake input of
  # git+https://git.argama.nix/<owner>/<repo>. Hydra has no declarative jobset
  # option, so this step stays manual.
}
