{ pkgs, ... }:
{
  virtualisation = {
    docker.enable = true;
    libvirtd.enable = pkgs.zfs.meta.available && pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform;
  };
}
