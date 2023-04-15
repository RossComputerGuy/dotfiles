{ config, lib, pkgs, ... }:
with lib;
let
  dbus-sway-environment = pkgs.writeTextFile {
    name = "dbus-sway-environment";
    destination = "/bin/dbus-sway-environment";
    executable = true;

    text = ''
      export XDG_DATA_DIRS=$XDG_DATA_DIRS:/var/lib/flatpak/exports/share
      dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway XDG_DATA_DIRS
      systemctl --user import-environment XDG_DATA_DIRS WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
      systemctl --user stop pipewire pipewire-media-session xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
      systemctl --user start pipewire pipewire-media-session xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk
    '';
  };
in
{
  imports = [
    ./home.nix
  ];

  xdg.configFile."alacritty/alacritty.yml".source = ./config/alacritty/alacritty.yml;
  xdg.configFile."alacritty/alacritty-device.yml".source = ./config/alacritty/alacritty-linux.yml;
  xdg.configFile."eww/eww.yuck".source = ./config/eww/eww.yuck;
  xdg.configFile."eww/eww.scss".source = ./config/eww/eww.scss;
  xdg.configFile."mako/config".source = ./config/mako/config;
  xdg.configFile."nwg-drawer/drawer.css".source = ./config/nwg-drawer/drawer.css;
  xdg.configFile."sway/config".source = ./config/sway/config;
  xdg.configFile."swayidle/config".source = ./config/swayidle/config;
  xdg.configFile."i3/config".source = ./config/i3/config;
  xdg.configFile."electron-flags.conf".source = ./config/electron-flags.conf;
  xdg.configFile."mimeapps.list".source = ./config/mimeapps.list;
  xdg.configFile."nvim/lua/init.lua".source = ./config/nvim/lua/init.lua;
  fonts.fontconfig.enable = lib.mkForce true;
  home.file."Pictures/wallpaper.jpg".source = ./pictures/wallpaper.jpg;
  home.username = "ross";
  home.homeDirectory = mkForce "/home/ross";
  home.packages = with pkgs; [
    prismlauncher
    dbus-sway-environment
    eww-wayland
    nvimpager
    xdg-user-dirs
    alacritty
    solaar
    nwg-drawer
    mako
    dunst
    playerctl
    pamixer
    grim
    slurp
    wl-clipboard
    swaylock-effects
    i3lock-fancy
    corefonts
    noto-fonts
    noto-fonts-emoji
    dejavu_fonts
    migu
    xidlehook
    maim
    xclip
    xorg.xrandr
    papirus-icon-theme
    dejavu_fonts
  ];

  home.sessionVariables.MANPAGER = "nvimpager";
  home.sessionVariables.PAGER = "nvimpager";

  gtk = {
    enable = true;
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    font = {
      package = pkgs.dejavu_fonts;
      name = "Migu 1P Regular";
    };
  };
}
