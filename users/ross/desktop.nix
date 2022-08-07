{ config, pkgs, lib, ... }:
{
  home-manager.users.ross = {
    xdg.configFile."alacritty/alacritty.yml".source = ./config/alacritty/alacritty.yml;
    xdg.configFile."sway/config".source = ./config/sway/config;
    xdg.configFile."swayidle/config".source = ./config/swayidle/config;
    xdg.configFile."eww/eww.yuck".source = ./config/eww/eww.yuck;
    xdg.configFile."eww/eww.scss".source = ./config/eww/eww.scss;
    xdg.configFile."electron-flags.conf".source = ./config/electron-flags.conf;
    xdg.configFile."mimeapps.list".source = ./config/mimeapps.list;
    home.file."Pictures/wallpaper.jpg".source = ./pictures/wallpaper.jpg;
    fonts.fontconfig.enable = lib.mkForce true;
    home.packages = with pkgs; [
      nwg-drawer
      config.lib.computer-guy.eww-wayland
      mako
      wlogout
      playerctl
      pamixer
      grim
      slurp
      wl-clipboard
      config.lib.computer-guy.dbus-sway-environment
      swaylock-effects
      noto-fonts
      noto-fonts-cjk
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-emoji
      ipaexfont
      hanazono
      migu
      dejavu_fonts
      freefont_ttf
      gyre-fonts
      liberation_ttf
      unifont
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
	name = "DejaVu Sans";
      };
    };
  };
}
