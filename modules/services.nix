{ pkgs, ... }:
{
  services = {
    fwupd.enable = pkgs.valgrind.meta.available;
    udisks2.enable = true;
  };
}
