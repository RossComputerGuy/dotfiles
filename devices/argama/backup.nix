{
  config,
  lib,
  pkgs,
  ...
}:
let
  dataDir = "/var/lib/restic";

  # The machines that push here. Keep this the same as the machines that set
  # ross.backup.enable, because each name is both a rest-server account and a
  # directory below dataDir.
  clients = [
    "zeta3a"
    "hizack-b"
  ];

  keep = [
    "--keep-daily 7"
    "--keep-weekly 5"
    "--keep-monthly 12"
  ];
in
{
  # argama receives the backups for the fleet. Each machine pushes to its own
  # repository, reached through Caddy at backup.argama.nix.
  services.restic.server = {
    enable = true;
    listenAddress = "8000";
    inherit dataDir;
    # A client can add a snapshot but it cannot remove one. If an attacker takes
    # a machine, that machine cannot erase its own backup history.
    appendOnly = true;
    # A client sees only the repository that its own account can reach.
    privateRepos = true;
    prometheus = true;
  };

  # Caddy holds 443 for backup.argama.nix, so 8000 needs no opening of its own.
  # See web.nix.

  # The module makes an empty .htpasswd below dataDir, and privateRepos means
  # rest-server refuses every request that no account in that file matches. So
  # a new machine needs an account added by hand before its first backup. See
  # the README.
  #
  # This is the whole Apache package for one small command. htpasswd is the
  # only tool that adds an account and changes an account in the same step, and
  # a file written by hand instead would gain a second copy of a name each time
  # somebody set a password again.
  environment.systemPackages = [ pkgs.apacheHttpd ];

  # Because the server is append only, no client can prune. argama does it from
  # this side, straight on the repository files. Each password comes from
  # OpenBao, the same one the client uses.
  detsys.vaultAgent.systemd.services = lib.listToAttrs (
    map (
      machine:
      lib.nameValuePair "restic-prune-${machine}" {
        enable = true;
        environment = {
          changeAction = "none";
          template = ''
            RESTIC_PASSWORD={{ with secret "secret/data/${machine}/restic" }}{{ .Data.data.password }}{{ end }}
          '';
        };
      }
    ) clients
  );

  systemd.services = lib.listToAttrs (
    map (
      machine:
      lib.nameValuePair "restic-prune-${machine}" {
        description = "Remove the old snapshots of ${machine}";
        # A prune rewrites the repository, so it must not run while that machine
        # is writing a backup. Once a week, away from the nightly window.
        startAt = "Sun 05:00";
        after = [ "openbao.service" ];
        serviceConfig = {
          Type = "oneshot";
          # rest-server puts each account's repository below its own name when
          # privateRepos is on, so the files are here on the local disk.
          ExecStart = ''
            ${lib.getExe pkgs.restic} --repo ${dataDir}/${machine} \
              forget --prune ${lib.concatStringsSep " " keep}
          '';
          # The repository belongs to the restic user, and this rewrites it.
          User = "restic";
          Group = "restic";
        };
      }
    ) clients
  );
}
