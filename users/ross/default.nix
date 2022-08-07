{ home-manager, pkgs, expr, dbus-sway-environment, ... }:
{
  users.users.ross = {
    isNormalUser = true;
    home = "/home/ross";
    description = "Tristan Ross";
    extraGroups = [ "wheel" "docker" "adbusers" "games" ];
  };

  home-manager.users.ross = {
    xdg.configFile."alacritty/alacritty.yml".source = ./config/alacritty/alacritty.yml;
    xdg.configFile."sway/config".source = ./config/sway/config;
    xdg.configFile."eww/eww.yuck".source = ./config/eww/eww.yuck;
    xdg.configFile."eww/eww.scss".source = ./config/eww/eww.scss;
    xdg.configFile."electron-flags.conf".source = ./config/electron-flags.conf;
    xdg.configFile."mimeapps.list".source = ./config/mimeapps.list;
    home.file."Pictures/wallpaper.jpg".source = ./pictures/wallpaper.jpg;
    home.packages = with pkgs; [
      nwg-drawer
      eww-wayland
      mako
      wlogout
      playerctl
      pamixer
      xdg-user-dirs
      grim
      slurp
      wl-clipboard
      jq
      dbus-sway-environment
      swaylock-effects
    ];
    gtk = {
      enable = true;
      iconTheme = {
        package = pkgs.papirus-icon-theme;
	name = "Papirus-Dark";
      };
      theme = {
        package = expr.tokyonight-gtk-themes;
	name = "material-tokyo-night";
      };
    };
    programs.git = {
      userEmail = "tristan.ross@midstall.com";
      userName = "Tristan Ross";
    };
  };
}
