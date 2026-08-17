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

  # Give a machine its account and its repository in one step. Neither password
  # is typed, shown, or written to a file, so neither can be read from a shell
  # history or from the list of processes.
  addClient = pkgs.writeShellApplication {
    name = "argama-add-restic-client";
    runtimeInputs = [
      pkgs.apacheHttpd
      pkgs.openbao
      pkgs.jq
      pkgs.util-linux
    ];
    text = ''
      if [ $# -ne 1 ]; then
        echo "usage: argama-add-restic-client <machine>" >&2
        exit 1
      fi
      machine="$1"
      export BAO_ADDR="''${BAO_ADDR:-http://127.0.0.1:8200}"

      # This command has to be root, because it writes a file that belongs to
      # the restic user. sudo gives root a home with no token in it, so find the
      # token of the person who called sudo.
      if [ -z "''${BAO_TOKEN:-}" ] && [ -n "''${SUDO_USER:-}" ]; then
        home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
        if [ -r "$home/.vault-token" ]; then
          BAO_TOKEN=$(cat "$home/.vault-token")
          export BAO_TOKEN
        fi
      fi

      # Ask before anything changes. htpasswd used to run first, so a missing
      # token left the machine with an account whose password nothing recorded.
      if ! bao token lookup > /dev/null 2>&1; then
        echo "No OpenBao token that works." >&2
        echo "Run: bao login -method=userpass username=ross" >&2
        exit 1
      fi

      # The list below comes from this file, so the two always agree. The weekly
      # prune reads the same list, and a repository that the prune does not know
      # grows without end.
      known=0
      for c in ${lib.concatStringsSep " " clients}; do
        if [ "$c" = "$machine" ]; then
          known=1
        fi
      done

      if [ "$known" -eq 0 ]; then
        echo "$machine is not in the clients list in devices/argama/backup.nix." >&2
        echo "Add it there first, then rebuild, then run this again." >&2
        exit 1
      fi

      # The repository password is the one that encrypts the data. A second one
      # would make every snapshot already in the repository unreadable, and
      # restic gives no way back. So this command adds a machine and it never
      # changes one.
      if bao kv get -field=password "secret/$machine/restic" > /dev/null 2>&1; then
        echo "secret/$machine/restic exists already." >&2
        echo "A new repository password would lose every snapshot it holds." >&2
        exit 1
      fi

      # Hexadecimal, because the first one goes inside a URL. base64 gives "/"
      # and "+", which end the user name early and point the address somewhere
      # else. 128 bits opens the connection, 256 bits encrypts the repository.
      http=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')
      repo=$(od -An -tx1 -N32 /dev/urandom | tr -d ' \n')

      # The file belongs to the restic user with mode 0700, and htpasswd writes
      # it again in place, so this runs as that user and keeps the owner.
      printf '%s' "$http" \
        | runuser -u restic -- htpasswd -B -i ${dataDir}/.htpasswd "$machine"

      # Standard input, not the command line. An argument would show in ps for
      # as long as the command runs.
      jq -n \
          --arg r "rest:https://$machine:$http@backup.argama.nix/" \
          --arg p "$repo" \
          '{repository:$r, password:$p}' \
        | bao kv put "secret/$machine/restic" -

      echo "Added $machine. Neither password was shown, and neither is needed." >&2
      echo "The agent on $machine finds them inside 15 seconds." >&2
    '';
  };
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
  environment.systemPackages = [
    pkgs.apacheHttpd
    addClient
  ];

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
