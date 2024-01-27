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
  xdg.configFile."electron-flags.conf".source = ./config/electron-flags.conf;
  xdg.configFile."mimeapps.list".source = ./config/mimeapps.list;
  xdg.configFile."nvim/lua/init.lua".source = ./config/nvim/lua/init.lua;
  fonts.fontconfig.enable = lib.mkForce true;
  home.file."Pictures/wallpaper.jpg".source = ./pictures/wallpaper.jpg;

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
    solaar
    dunst
    playerctl
    pamixer
    grim
    slurp
    wl-clipboard
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
    swww
    waypaper
    brightnessctl
    kanshi
    (prismlauncher.override {
      glfw = pkgs.glfw-wayland-minecraft;
    })
  ];

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

  programs.ags = {
    enable = true;
    configDir = ./config/ags;
    extraPackages = with pkgs; [ accountsservice brightnessctl ];
  };

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

  wayland.windowManager.hyprland = {
    enable = true;
    plugins = [
      "${pkgs.hycov}/lib/libhycov.so"
    ];
    settings = {
      "$mod" = "SUPER";
      env = [
        "QT_QPA_PLATFORM,wayland"
        "MOZ_ENABLE_WAYLAND,1"
      ];
      exec-once = [
        "ags"
        "waypaper --restore"
        "kanshi &"
      ];
      general = {
        gaps_in = 4;
        gaps_out = 4;
        gaps_workspaces = 4;
        resize_on_border = true;
      };
      gestures = {
        workspace_swipe = true;
        workspace_swipe_forever = true;
        workspace_swipe_numbered = true;
      };
      decoration.rounding = 3;
      bindm = [
        "$mod,mouse:272,movewindow"
      ];
      bindle = [
        ",XF86MonBrightnessUp,exec,brightnessctl s +10%"
        ",XF86MonBrightnessDown,exec,brightnessctl s 10%-"
        ",XF86AudioRaiseVolume,exec,pamixer -ui 2"
        ",XF86AudioLowerVolume,exec,pamixer -ud 2"
      ];
      bindl = [
        ",XF86AudioPlay,exec,playerctl play-pause"
        ",XF86AudioStop,exec,playerctl stop"
        ",XF86AudioPause,exec,playerctl play-pause"
        ",XF86AudioPrev,exec,playerctl previous"
        ",XF86AudioNext,exec,playerctl next"
        ",XF86AudioMute,exec,pamixer --toggle-mute"
      ];
      bind = [
        "$mod SHIFT, Q, exit"
        "$mod SHIFT, R, exec, hyprctl reload"
        "$mod, Q, killactive"
        "$mod, Return, exec, alacritty"
        "$mod, D, exec, fuzzel"

        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        "$mod SHIFT, left, movewindow, l"
        "$mod SHIFT, right, movewindow, r"
        "$mod SHIFT, up, movewindow, u"
        "$mod SHIFT, down, movewindow, d"

        ",XF86LaunchA,hycov:toggleoverview"

        "$mod, F, togglefloating"
        "$mod SHIFT, F, pin"

        ",Print,exec,grim - | wl-copy"
        "SHIFT,Print,exec,slurp | grim -g - - | wl-copy"

        "$mod,P,exec,grim - | wl-copy"
        "$mod SHIFT, P,exec,slurp | grim -g - - | wl-copy"
      ] ++ (
        builtins.concatLists (builtins.genList (
          x:
            let
              ws = let
                c = (x + 1) / 10;
              in builtins.toString (x + 1 - (c * 10));
            in [
              "$mod, ${ws}, workspace, ${toString (x + 1)}"
              "$mod SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
            ]) 10));
    };
  };
}
