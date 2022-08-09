{ config, pkgs, lib, ... }:
{
  home-manager.users.ross = {
    xdg.configFile."alacritty/alacritty.yml".source = ./config/alacritty/alacritty.yml;
    xdg.configFile."eww/eww.yuck".source = ./config/eww/eww.yuck;
    xdg.configFile."eww/eww.scss".source = ./config/eww/eww.scss;
    xdg.configFile."mako/config".source = ./config/mako/config;
    xdg.configFile."nwg-drawer/drawer.css".source = ./config/nwg-drawer/drawer.css;
    xdg.configFile."sway/config".source = ./config/sway/config;
    xdg.configFile."swayidle/config".source = ./config/swayidle/config;
    xdg.configFile."electron-flags.conf".source = ./config/electron-flags.conf;
    xdg.configFile."mimeapps.list".source = ./config/mimeapps.list;
    home.file."Pictures/wallpaper.jpg".source = ./pictures/wallpaper.jpg;
    fonts.fontconfig.enable = lib.mkForce true;
    home.packages = with pkgs; [
      alacritty
      nwg-drawer
      config.lib.computer-guy.eww-wayland
      mako
      playerctl
      pamixer
      grim
      slurp
      wl-clipboard
      config.lib.computer-guy.dbus-sway-environment
      swaylock-effects
      noto-fonts
      noto-fonts-emoji
      dejavu_fonts
      migu
    ];
    gtk = {
      enable = true;
      iconTheme = {
        package = pkgs.papirus-icon-theme;
	name = "Papirus-Dark";
      };
      theme = {
        package = config.lib.computer-guy.tokyonight-gtk-themes;
	name = "material-tokyo-night";
      };
      font = {
        package = pkgs.dejavu_fonts;
	name = "Migu 1P Regular";
      };
    };
  };
}
