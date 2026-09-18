{ lib, pkgs, ... }:
{
  imports = [
    ../../modules
  ];

  # COSMIC turns the scheduler on for every desktop, and the installer image
  # brings the power daemon with the hardware profiles. Neither package builds
  # for riscv64, so jegan and mu-gundam stopped with "Refusing to evaluate
  # package". That breaks `nix flake show` for the whole flake and not only for
  # the machine that cannot have them, because one failed output fails the
  # command. This asks each package which platforms it serves rather than
  # naming riscv64 here, so a later nixpkgs that gains the platform needs no
  # edit.
  services.system76-scheduler.enable = lib.mkForce (
    lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.system76-scheduler
  );
  hardware.system76.power-daemon.enable = lib.mkForce (
    lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.system76-power
  );

  nix.settings.auto-optimise-store = true;

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };

  # Most machines here are desktops. A headless machine sets the standard
  # profile in its own device file.
  ross.profile = lib.mkDefault "desktop";
}
