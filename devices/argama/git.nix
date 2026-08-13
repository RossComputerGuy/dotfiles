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
    };
  };

  # Hydra reads a jobset from a flake URL, so it can build straight from
  # Forgejo. Add the jobset in the Hydra web interface with a flake input of
  # git+https://git.argama.nix/<owner>/<repo>. Hydra has no declarative jobset
  # option, so this step stays manual.
}
