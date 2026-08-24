{
  # pcscd is the PC/SC daemon. It owns the smartcard reader and lets more than
  # one application speak to the card through it. A YubiKey is a smartcard, so
  # yubikey-manager, the PIV and OpenPGP applets, and openssh with a PKCS#11
  # provider all need this daemon.
  #
  # Every machine gets it, and not only the machines that hold a key today. The
  # unit starts from its socket, so a machine with no reader runs no process
  # and keeps the cost at one socket unit.
  #
  # GnuPG has a second driver for the same hardware. scdaemon opens the USB
  # device directly unless it is told to use PC/SC, and the first one to open
  # the device keeps it. If gpg sees the card but another tool does not, or the
  # other way around, this is the cause.
  services.pcscd.enable = true;
}
