{ lib, ... }:
let
  cert = ../certs/argama-root.crt;
  # The file is not in the repository until an operator puts it there, and a
  # missing path is an evaluation error rather than a warning. Read it only
  # when it exists, so every machine keeps building in the meantime.
  present = builtins.pathExists cert;
in
{
  # argama signs every name in the .nix zone with its own authority, so nothing
  # trusts those certificates until this root is installed. Without it curl,
  # git, restic and a browser each refuse the connection, and each one words the
  # refusal differently, so the same fault reads like four separate ones.
  #
  # The root certificate is public. Only the private half matters, and that one
  # never leaves the YubiKey, so this belongs in the repository next to the
  # configuration that needs it rather than in OpenBao.
  #
  # Put it there with, on argama:
  #   bao kv get -field=certificate secret/argama/ca > certs/argama-root.crt
  security.pki.certificateFiles = lib.optional present cert;

  warnings = lib.optional (!present) ''
    certs/argama-root.crt is missing, so this machine does not trust argama's
    certificate authority. Every https name in the .nix zone will be refused.
    See modules/pki.nix.
  '';
}
