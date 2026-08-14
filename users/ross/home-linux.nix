{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
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

  # users/common.nix calls this file with the NixOS module arguments, so `config`
  # is the NixOS config on a machine. A standalone home configuration has no ross
  # options, and every one of those is a desktop, so fall back to true there.
  #
  # Without this gate a headless machine still gets Firefox, LibreOffice, Mozc
  # and the GTK stack. The flake overlay patches libdrm and fonttools, so no
  # cache can supply anything above them and the machine builds Firefox itself.
  #
  # Read the profile only from this file, never from home.nix. common.nix merges
  # home.nix into the result AND this file imports it, so Home Manager evaluates
  # home.nix a second time with its own config, which has no ross options. The
  # two evaluations would then disagree and the merge would stop.
  desktop = (config.ross.profile or "desktop") == "desktop";

  native = pkgs.stdenv.hostPlatform == pkgs.stdenv.buildPlatform;
in
{
  imports = [
    ./home.nix
  ];

  xdg.mime = {
    sharedMimeInfoPackage = lib.mkForce pkgs.pkgsBuildBuild.shared-mime-info;
    desktopFileUtilsPackage = lib.mkForce pkgs.pkgsBuildBuild.desktop-file-utils;
  };

  xdg.configFile."electron-flags.conf".source = ./config/electron-flags.conf;
  xdg.configFile."mimeapps.list".source = ./config/mimeapps.list;
  fonts.fontconfig.enable = lib.mkForce (desktop && native);
  home.file."Pictures/wallpaper.jpg".source = ./pictures/wallpaper.jpg;
  home.file.".gdbinit".source = pkgs.fetchurl {
    url = "https://github.com/cyrus-and/gdb-dashboard/raw/05b31885798f16b1c1da9cb78f8c78746dd3557e/.gdbinit";
    hash = "sha256-i9JJuGQpd/2cB6f/VyfZ3jVWxIz1ZxLb0j5UmM/0ELI=";
  };

  home.username = "ross";
  home.homeDirectory = mkForce "/home/ross";
  home.packages =
    with pkgs;
    lib.optionals desktop [
      dbus-sway-environment
      xdg-user-dirs
      #solaar
      playerctl
      grim
      slurp
      wl-clipboard
      migu
      maim
      xclip
      brightnessctl
      kanshi
      corefonts
      noto-fonts
      dejavu_fonts
    ]
    ++ lib.optionals (desktop && !pkgs.stdenv.hostPlatform.isRiscV64 && native) [
      (prismlauncher.override {
        glfw3-minecraft = pkgs.glfw3-minecraft.overrideAttrs (
          f: p: {
            patches = [
              (builtins.elemAt p.patches 0)
            ];

            prePatch = ''
              patches+=(${
                pkgs.fetchFromGitHub {
                  owner = "diniamo";
                  repo = "glfw-wayland";
                  rev = "8c52ae47f406ba455fd19b7539c6f895652c558d";
                  hash = "sha256-7FnfxWeJIndHBPtpoguWUBOAE/d/oLDFQlddugfkg5c=";
                }
              }/patches/*.patch)
            '';
          }
        );
      })
      pamixer
      noto-fonts-color-emoji
      libreoffice
      # Chat
      signal-desktop
      vesktop # Discord (no official aarch64 client)
      # fluffychat (Matrix): meta.broken is set on every platform in this nixpkgs
      # pin. Put it back when upstream unbreaks it.
      # Slack: ferdium SIGTRAPs on aarch64 (upstream bug); pending a web-app launcher.
    ]
    ++ lib.optional (desktop && native) pkgs.papirus-icon-theme
    # nvimpager is not a desktop program. home.nix makes it the git pager on every
    # native machine, so a headless one still needs it. It stays after papirus so
    # that a desktop keeps the order it had, and its store path does not move.
    ++ lib.optional native pkgs.nvimpager;

  home.sessionVariables = lib.mkIf native {
    MANPAGER = "nvimpager";
    PAGER = "nvimpager";
  };

  i18n.inputMethod = {
    enable = desktop && native && !pkgs.stdenv.hostPlatform.isRiscV64;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = [ pkgs.fcitx5-mozc ];

      # fcitx5-configtool links KDE Frameworks 6.28, which now builds PySide6
      # bindings, and pyside6 build-depends on qtwebengine. That is a multi hour
      # Chromium build that no cache can supply, because this flake's overlay
      # patches libdrm, libapparmor and fonttools. The profile is declared
      # below, so the GUI is not needed.
      fcitx5-with-addons = pkgs.qt6Packages.fcitx5-with-addons.override {
        withConfigtool = false;
      };

      # Stylix's fcitx5 theme makes Home Manager own the whole ~/.config/fcitx5
      # directory as a read only link, so a profile that fcitx5 wrote itself
      # would be moved aside and could never come back. Declare it instead.
      # This is the profile that was on disk before Home Manager took over.
      settings.inputMethod = {
        "Groups/0" = {
          Name = "デフォルト";
          "Default Layout" = "us";
          DefaultIM = "mozc";
        };
        "Groups/0/Items/0".Name = "keyboard-us";
        "Groups/0/Items/1".Name = "mozc";
        GroupOrder."0" = "デフォルト";
      };
    };
  };

  gtk = {
    # Prevents mass rebuild
    enable = desktop && native;
    iconTheme = lib.mkIf (desktop && native) {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  # home.nix enables ghostty on every native machine, because it cannot read the
  # profile. Force it off where there is no screen.
  #
  # ghostty.terminfo is not an answer for a headless machine. It is an output of
  # the same derivation, so it still builds ghostty and GTK 4. Send the terminfo
  # over with "infocmp -x | ssh argama tic -x -" once instead.
  programs.ghostty.enable = lib.mkForce (desktop && native && !pkgs.stdenv.hostPlatform.isRiscV64);

  programs.firefox = {
    enable = desktop && !pkgs.stdenv.hostPlatform.isRiscV;

    # Firefox keeps its own list of authorities and does not read the system
    # one, so security.pki in modules/pki.nix does nothing for it. Both lines
    # are here on purpose: ImportEnterpriseRoots reads the system store where
    # the platform supports it, and Install names the file outright where it
    # does not.
    policies.Certificates = lib.mkIf (builtins.pathExists ../../certs/argama-root.crt) {
      ImportEnterpriseRoots = true;
      Install = [ "${../../certs/argama-root.crt}" ];
    };
    package = pkgs.firefox.overrideAttrs (old: {
      buildCommand = old.buildCommand + ''
        mkdir -p $out/gmp-widevinecdm/system-installed
        ln -s "${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm/_platform_specific/linux_arm64/libwidevinecdm.so" $out/gmp-widevinecdm/system-installed/libwidevinecdm.so
        ln -s "${pkgs.widevine-cdm}/share/google/chrome/WidevineCdm/manifest.json" $out/gmp-widevinecdm/system-installed/manifest.json
        wrapProgram "$oldExe" \
          --set MOZ_GMP_PATH "$out/gmp-widevinecdm/system-installed"
      '';
    });

    # Both of these are per machine. Firefox names a profile it creates itself
    # at random, and zeta3a keeps its profile under the XDG path while hizack-b
    # keeps its own under ~/.mozilla. See modules/profile.nix.
    #
    # users/common.nix calls this file with the NixOS module arguments and hands
    # the result to home-manager.users, so `config` here is the NixOS config on
    # a machine and the Home Manager config in a standalone home configuration.
    # The fallback covers the standalone case, which has no ross options.
    configPath = config.ross.firefoxConfigPath or ".mozilla/firefox";

    profiles.default = {
      id = 0;
      path = config.ross.firefoxProfilePath or "default";
    };
  };

  # The desktop is COSMIC. Both of these auto enable on any Linux and would add
  # an autostart entry that runs at every login, plus theme packages nothing
  # reads. The gnome one runs gnome-extensions, the kde one runs
  # plasma-apply-lookandfeel.
  stylix.targets.gnome.enable = false;
  stylix.targets.kde.enable = false;

  # The gtk target turns gtk.enable on by itself, which contradicts the gate
  # above and stops the evaluation. It also brings in the theme, the icons and
  # the cursors, which a machine with no screen does not read.
  stylix.targets.gtk.enable = desktop && native;

  stylix.targets.firefox = {
    profileNames = [ "default" ];
    # Without this you only get font preferences and reader-mode colors, not
    # actual chrome theming.
    firefoxGnomeTheme.enable = true;
  };
}
