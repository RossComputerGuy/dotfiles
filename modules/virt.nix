{ pkgs, ... }:
{
  virtualisation = {
    docker.enable = true;
    libvirtd.enable = pkgs.zfs.meta.available;
  };
}
