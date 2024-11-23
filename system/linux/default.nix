{ config, pkgs, lib, ... }:
{
  time.timeZone = "America/Los_Angeles";
  hardware.enableRedistributableFirmware = true;

  # Virtualization
  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = pkgs.zfs.meta.available;

  # Network Configuration
  security.rtkit.enable = true;

  services.resolved.enable = true;
  networking.networkmanager.enable = true;
  networking.firewall.checkReversePath = "loose";

  # Keyboard & Input

  i18n.defaultLocale = "ja_JP.UTF-8";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "ja_JP.UTF-8/UTF-8" ];

  # Packages
  services.fwupd.enable = pkgs.valgrind.meta.available;
  services.udisks2.enable = true;
  programs.git.enable = true;
  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    lm_sensors
    fwupd-efi
    nixpkgs-review
  ] ++ lib.optionals (pkgs.haskell.compiler.ghc965.meta.available) [
    pkgs.nix-output-monitor
    pkgs.nix-diff
    pkgs.nixfmt-rfc-style
  ];

  system.stateVersion = "23.05";
}
