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
  #
  # The gate only turns the daemons off, and only where the package has no
  # platform. An earlier version set each option to the platform test itself.
  # That also turned both daemons on for every machine that had them off,
  # because the test is true on aarch64. hizack-b is an Apple Silicon laptop
  # and is not System76 hardware. The power daemon rescanned the PCI bus while
  # brcmfmac started, the BCM4387 firmware stopped to answer commands, and the
  # machine lost Wi-Fi.
  services.system76-scheduler.enable = lib.mkIf (
    !lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.system76-scheduler
  ) (lib.mkForce false);
  hardware.system76.power-daemon.enable = lib.mkIf (
    !lib.meta.availableOn pkgs.stdenv.hostPlatform pkgs.system76-power
  ) (lib.mkForce false);

  nix.settings.auto-optimise-store = true;

  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };

  # Most machines here are desktops. A headless machine sets the standard
  # profile in its own device file.
  ross.profile = lib.mkDefault "desktop";
}
