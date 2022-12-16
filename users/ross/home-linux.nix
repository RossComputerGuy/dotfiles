{ config, lib, pkgs, ... }:
let
  dbus-sway-environment = pkgs.writeTextFile {
    name = "dbus-sway-environment";
    destination = "/bin/dbus-sway-environment";
    executable = true;

    text = ''
      export XDG_DATA_DIRS=$XDG_DATA_DIRS:/var/lib/flatpak/exports/share
      dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway
      systemctl --user import-environment XDG_DATA_DIRS=$XDG_DATA_DIRS
      systemctl --user stop pipewire pipewire-media-session xdg-desktop-portal xdg-desktop-portal-wlr
      systemctl --user start pipewire pipewire-media-session xdg-desktop-portal xdg-desktop-portal-wlr
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
  home.packages = with pkgs; [
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
    noto-fonts
    noto-fonts-emoji
    dejavu_fonts
    migu
    xidlehook
    maim
    xclip
    xorg.xrandr
    papirus-icon-theme
    libtokyo
    dejavu_fonts
  ];

  home.sessionVariables.MANPAGER = "nvimpager";
  home.sessionVariables.PAGER = "nvimpager";
  home.sessionVariables.XDG_DATA_DIRS = "${config.environment.sessionVariables.XDG_DATA_DIRS}:/var/lib/flatpak/exports/share";

  gtk = {
    enable = true;
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    theme = {
      package = pkgs.libtokyo;
      name = "Tokyo-Night";
    };
    font = {
      package = pkgs.dejavu_fonts;
      name = "Migu 1P Regular";
    };
  };
}
