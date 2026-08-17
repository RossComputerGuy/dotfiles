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
      # The terminal description that ghostty needs. ssh sends TERM to the far
      # machine, so a machine with no entry for xterm-ghostty answers "can't
      # find terminal definition" at every login, and a program that draws a
      # screen then behaves badly. This is the terminfo output alone, a few
      # kilobytes, and not the terminal itself.
      #
      # jegan misses out. ghostty asks for pandoc for its documentation, pandoc
      # asks for GHC, and GHC has no bootstrap on riscv64.
      pkgs.ghostty.terminfo
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
