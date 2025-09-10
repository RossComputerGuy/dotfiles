{ config, lib, pkgs, ... }:
let
  inherit (config.ross) profile;
in
{
  programs = {
    dconf.enable = true;
    git.enable = true;
    zsh.enable = true;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
    adb.enable = !pkgs.stdenv.hostPlatform.isRiscV64;
    firefox.enable = true;
  };

  environment.systemPackages = with pkgs; [
    lm_sensors
    fwupd-efi
    nixpkgs-review
  ] ++ lib.optionals (!pkgs.stdenv.hostPlatform.isRiscV64) [
    pkgs.nix-output-monitor
    pkgs.nix-diff
    pkgs.nixfmt-rfc-style
  ] ++ lib.optional (stdenv.hostPlatform == stdenv.buildPlatform && profile == "desktop") papirus-icon-theme;
}
