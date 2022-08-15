{ config, pkgs, ... }:
{
  xdg.configFile."nvim/lua/init.lua".source = ./config/nvim/lua/init.lua;
  home.packages += with pkgs; [
    nvimpager
    xdg-user-dirs
  ];
  home.sessionVariables.MANPAGER = "nvimpager";
  home.sessionVariables.PAGER = "nvimpager";
}
