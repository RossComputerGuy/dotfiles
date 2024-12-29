{ config, lib, pkgs, inputs, ... }:
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

  xdg.configFile."alacritty/alacritty.toml".source = ./config/alacritty/alacritty.toml;
  xdg.configFile."alacritty/alacritty-device.toml".source = ./config/alacritty/alacritty-linux.toml;
  xdg.configFile."electron-flags.conf".source = ./config/electron-flags.conf;
  xdg.configFile."mimeapps.list".source = ./config/mimeapps.list;
  xdg.configFile."nvim/lua/init.lua".source = ./config/nvim/lua/init.lua;
  fonts.fontconfig.enable = lib.mkForce true;
  home.file."Pictures/wallpaper.jpg".source = ./pictures/wallpaper.jpg;
  home.file.".gdbinit".source = pkgs.fetchurl {
    url = "https://github.com/cyrus-and/gdb-dashboard/raw/05b31885798f16b1c1da9cb78f8c78746dd3557e/.gdbinit";
    hash = "sha256-i9JJuGQpd/2cB6f/VyfZ3jVWxIz1ZxLb0j5UmM/0ELI=";
  };

  xdg.configFile."waypaper/config.ini".source = pkgs.writeText "waypaper.ini" (generators.toINI {} {
    Settings = {
      folder = "/home/ross/Pictures";
      wallpaper = "/home/ross/Pictures/wallpaper.jpg";
      backend = "swww";
      monitors = "All";
      fill = "Fill";
      sort = "name";
      color = "#1a1b26";
      swww_transition_type = "any";
      swww_transition_step = 90;
      swww_transition_angle = 0;
      swww_transition_duration = 3;
    };
  });

  home.username = "ross";
  home.homeDirectory = mkForce "/home/ross";
  home.packages = with pkgs; [
    dbus-sway-environment
    nvimpager
    xdg-user-dirs
    alacritty
    #solaar
    dunst
    playerctl
    pamixer
    grim
    slurp
    wl-clipboard
    migu
    xidlehook
    maim
    xclip
    papirus-icon-theme
    swww
    waypaper
    brightnessctl
    kanshi
    corefonts
    noto-fonts
    noto-fonts-emoji
    dejavu_fonts
  ] ++ lib.optional (pkgs.openjdk.meta.available) (prismlauncher.override {
    glfw3-minecraft = pkgs.glfw-wayland-minecraft;
  });

  home.sessionVariables.MANPAGER = "nvimpager";
  home.sessionVariables.PAGER = "nvimpager";

  gtk = {
    enable = true;
    cursorTheme = {
      package = pkgs.shuba-cursors;
      name = "Shuba";
    };
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    font = {
      package = pkgs.dejavu_fonts;
      name = "Migu 1P Regular";
    };
    theme = {
      package = pkgs.tokyo-night-gtk;
      name = "Tokyonight-Dark-BL";
    };
  };

  /*programs.ags = {
    enable = true;
    package = pkgs.ags;
    configDir = ./config/ags;
    extraPackages = with pkgs; [ accountsservice brightnessctl ];
  };*/

  programs.fuzzel = {
    enable = true;
    settings = {
      main = {
        icon-theme = "Papirus-Dark";
        terminal = "${lib.getExe pkgs.alacritty} -e";
      };
      colors = {
        background = "1a1b26ff";
        text = "ffffffff";
        border = "ffffff14";
        selection = "c0caf5ff";
      };
    };
  };
}
