{ config, pkgs, ... }:
{
  imports = [
    ./home.nix
  ];

  xdg.configFile."nvim/lua/init.lua".source = ./config/nvim/lua/init.lua;
  home.packages = with pkgs; [
    nvimpager
    xdg-user-dirs
  ];
  home.sessionVariables.MANPAGER = "nvimpager";
  home.sessionVariables.PAGER = "nvimpager";
  home.sessionVariables.XDG_DATA_DIRS = "${config.environment.sessionVariables.XDG_DATA_DIRS}:/var/lib/flatpak/exports/share";
}
