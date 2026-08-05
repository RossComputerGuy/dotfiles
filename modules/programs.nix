{
  config,
  lib,
  pkgs,
  ...
}:
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
  };

  environment.systemPackages =
    with pkgs;
    [
      lm_sensors
      nixpkgs-review
    ]
    ++ lib.optionals (!pkgs.stdenv.hostPlatform.isRiscV64) [
      pkgs.nix-output-monitor
      pkgs.nix-diff
      pkgs.nixfmt
      pkgs.fwupd-efi
      pkgs.android-tools
    ]
    ++ lib.optional (
      stdenv.hostPlatform == stdenv.buildPlatform && profile == "desktop"
    ) papirus-icon-theme;
}
