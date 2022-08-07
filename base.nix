# Base Configuration for nixOS

{ config, pkgs, modulesPath, ... }:
let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-22.05.tar.gz";
  expr = import ./pkgs { inherit pkgs; };
in
{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
      (import "${home-manager}/nixos")
      (import ./users { inherit pkgs; inherit expr; inherit home-manager; })
    ];
  nixpkgs.config.allowUnfree = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?

  # "Other" System Configuration
  time.timeZone = "America/Los_Angeles";
  systemd.enableUnifiedCgroupHierarchy = true;

  # Virtualization
  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;

  # Network Configuration
  security.rtkit.enable = true;

  networking.nameservers = [ "127.0.0.1" "::1" ];

  services.dnscrypt-proxy2 = {
    enable = true;
  };

  systemd.services.dnscrypt-proxy2.serviceConfig = {
    StateDirectory = "dnscrypt-proxy";
  };

  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "none";

  # Keyboard & Input

  i18n.defaultLocale = "ja_JP.UTF-8";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "ja_JP.UTF-8/UTF-8" ];
}
