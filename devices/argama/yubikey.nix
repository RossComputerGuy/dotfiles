{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Where the encrypted unseal shares live. Each file is one share, encrypted to
  # the YubiKey's OpenPGP key, so the plain share never touches this disk.
  shareDir = "/var/lib/openbao/unseal-shares";

  unseal = pkgs.writeShellApplication {
    name = "argama-unseal";
    runtimeInputs = [
      pkgs.curl
      pkgs.gnupg
      pkgs.openbao
    ];
    text = ''
      # Decrypt each share with the YubiKey and give it to OpenBao. The YubiKey
      # asks for a touch once for each share.
      export BAO_ADDR="''${BAO_ADDR:-http://127.0.0.1:8200}"

      # nullglob makes an empty directory give an empty array instead of the
      # pattern itself. Do not reach for compgen here: writeShellApplication
      # runs the small bash, which is built without readline, and that build
      # carries no programmable completion builtins.
      shopt -s nullglob
      shares=( ${shareDir}/*.asc )

      if [ ''${#shares[@]} -eq 0 ]; then
        echo "argama-unseal: no shares in ${shareDir}" >&2
        echo "Run bao operator init with -pgp-keys first. See the README." >&2
        exit 1
      fi

      # "bao operator unseal -" does not read standard input. OpenBao takes one
      # argument and nothing else, so a "-" becomes the key itself and the API
      # answers "'key' must be a valid hex or base64 string". Giving no argument
      # makes it ask on a terminal, and it refuses a pipe: "file descriptor 0 is
      # not a terminal".
      #
      # That leaves the key as an argument, which every local account can read
      # from /proc. Jellyfin and each arr service run as their own user on this
      # machine, so a service that is taken over can watch for it. Speak to the
      # API instead. printf is a shell builtin, so the key stays inside this
      # process. The share is 64 hex characters, so it needs no JSON escaping.
      for share in "''${shares[@]}"; do
        echo "argama-unseal: $share" >&2
        key="$(gpg --quiet --decrypt "$share")"
        if ! answer="$(printf '{"key":"%s"}' "$key" |
          curl -sS --fail-with-body -X PUT --data-binary @- \
            "$BAO_ADDR/v1/sys/unseal")"; then
          echo "argama-unseal: $answer" >&2
          exit 1
        fi
      done
      unset key

      bao status
    '';
  };

  # An AppRole secret ID must not travel in the clear. This wraps one in a
  # single use token, so the machine that receives it is the only reader, and a
  # token which arrives already used proves it was intercepted.
  issueApprole = pkgs.writeShellApplication {
    name = "argama-issue-approle";
    runtimeInputs = [ pkgs.openbao ];
    text = ''
      if [ $# -ne 1 ]; then
        echo "usage: argama-issue-approle <machine>" >&2
        exit 1
      fi
      machine="$1"
      export BAO_ADDR="''${BAO_ADDR:-http://127.0.0.1:8200}"

      echo "role_id for $machine:" >&2
      bao read -field=role_id "auth/approle/role/$machine/role-id"
      echo >&2
      echo "wrapping token for the secret_id, good for 5 minutes:" >&2
      bao write -f -wrap-ttl=300s -field=wrapping_token \
        "auth/approle/role/$machine/secret-id"
    '';
  };
in
{
  environment.systemPackages = [
    unseal
    issueApprole
    # The YubiKey tools an operator needs on this machine.
    pkgs.yubikey-manager
    pkgs.yubico-piv-tool
    # ykchalresp and ykpersonalize, for the challenge and answer slot. argama
    # does not open its pools that way, because a daily carry cannot answer at
    # every boot, but the tools belong here for a recovery. See the README.
    pkgs.yubikey-personalization
    pkgs.gnupg
  ];

  # The YubiKey is a daily carry, so it is not in argama at boot. OpenBao stays
  # sealed until an operator plugs the key in and runs argama-unseal. The shares
  # here are encrypted to that key, so a copy of this directory is of no use on
  # its own.
  systemd.tmpfiles.rules = [
    "d ${shareDir} 0700 root root -"
  ];

  # An operator needs a smartcard reader to reach the YubiKey over ssh.
  services.pcscd.enable = true;
}
