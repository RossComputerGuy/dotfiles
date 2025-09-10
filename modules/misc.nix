{ pkgs, ... }:
{

  hardware.enableRedistributableFirmware = true;

  environment.stub-ld.enable = pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform;

  system.stateVersion = "23.05";
}
