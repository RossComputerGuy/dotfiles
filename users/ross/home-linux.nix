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

  xdg.mime = {
    sharedMimeInfoPackage = lib.mkForce pkgs.pkgsBuildBuild.shared-mime-info;
    desktopFileUtilsPackage = lib.mkForce pkgs.pkgsBuildBuild.desktop-file-utils;
  };

  xdg.configFile."alacritty/alacritty.toml".source = ./config/alacritty/alacritty.toml;
  xdg.configFile."alacritty/alacritty-device.toml".source = ./config/alacritty/alacritty-linux.toml;
  xdg.configFile."electron-flags.conf".source = ./config/electron-flags.conf;
  xdg.configFile."mimeapps.list".source = ./config/mimeapps.list;
  xdg.configFile."nvim/lua/init.lua".source = ./config/nvim/lua/init.lua;
  fonts.fontconfig.enable = lib.mkForce (pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform);
  home.file."Pictures/wallpaper.jpg".source = ./pictures/wallpaper.jpg;
  home.file.".gdbinit".source = pkgs.fetchurl {
    url = "https://github.com/cyrus-and/gdb-dashboard/raw/05b31885798f16b1c1da9cb78f8c78746dd3557e/.gdbinit";
    hash = "sha256-i9JJuGQpd/2cB6f/VyfZ3jVWxIz1ZxLb0j5UmM/0ELI=";
  };

  home.username = "ross";
  home.homeDirectory = mkForce "/home/ross";
  home.packages = with pkgs; [
    dbus-sway-environment
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
    maim
    xclip
    swww
    brightnessctl
    kanshi
    corefonts
    noto-fonts
    noto-fonts-emoji
    dejavu_fonts
  ] ++ lib.optional (!pkgs.stdenv.hostPlatform.isRiscV64) (prismlauncher.override {
    glfw3-minecraft = pkgs.glfw-wayland-minecraft;
  }) ++ lib.optionals (pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform) [
    pkgs.papirus-icon-theme
    pkgs.nvimpager
  ];

  home.sessionVariables = lib.mkIf (pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform) {
    MANPAGER = "nvimpager";
    PAGER = "nvimpager";
  };

  gtk = {
    enable = true;
    cursorTheme = {
      package = pkgs.shuba-cursors;
      name = "Shuba";
    };
    iconTheme = lib.mkIf (pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform) {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    font = {
      package = pkgs.dejavu_fonts;
      name = "Migu 1P Regular";
    };
    theme = {
      package = pkgs.tokyo-night-gtk;
      name = "Tokyonight-Dark";
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };
}
