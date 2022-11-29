# Base Configuration for nixOS

{ config, pkgs, modulesPath, lib, ... }:
let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-22.05.tar.gz";
in
{
  imports =
    [
      "${modulesPath}/installer/scan/not-detected.nix"
      "${home-manager}/nixos"
      ./users
      ./pkgs
    ];
  nixpkgs.config.allowUnfree = true;
  nix.settings.auto-optimise-store = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.05"; # Did you read the comment?

  # "Other" System Configuration
  time.timeZone = "America/Los_Angeles";
  systemd.enableUnifiedCgroupHierarchy = true;

  # Virtualization
  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;

  # Network Configuration
  security.rtkit.enable = true;

  services.resolved.enable = true;
  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "systemd-resolved";

  services.resolved.extraConfig = ''
    DNS=192.168.1.41
    DNS=100.82.207.123
    DNS=8.8.8.8
    DNS=8.8.4.4
    DNSOverTLS=yes
  '';

  # Keyboard & Input

  i18n.defaultLocale = "ja_JP.UTF-8";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "ja_JP.UTF-8/UTF-8" ];

  # Packages
  services.fwupd.enable = true;
  programs.git.enable = true;

  environment.systemPackages = with pkgs; [
    sumneko-lua-language-server
    vala-language-server
    clang-tools
    tree-sitter
    gcc
    rnix-lsp
    fd
    ripgrep
    lm_sensors
    fwupd-efi
  ];
}
