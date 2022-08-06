# Base Configuration for nixOS

{ config, pkgs, modulesPath, ... }:
let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-22.05.tar.gz";
  expr = import ./pkgs { inherit pkgs; };

  dbus-sway-environment = pkgs.writeTextFile {
    name = "dbus-sway-environment";
    destination = "/bin/dbus-sway-environment";
    executable = true;

    text = ''
      dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway
      systemctl --user stop pipewire pipewire-media-session xdg-desktop-portal xdg-desktop-portal-wlr
      systemctl --user start pipewire pipewire-media-session xdg-desktop-portal xdg-desktop-portal-wlr
    '';
  };
in
{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
      (import "${home-manager}/nixos")
    ];
  nixpkgs.config.allowUnfree = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?

  # "Other" System Configuration
  time.timeZone = "America/Los_Angeles";
  systemd.enableUnifiedCgroupHierarchy = true;


  services.udev.extraRules = ''
    # This rule is needed for basic functionality of the controller in Steam and keyboard/mouse emulation
    SUBSYSTEM=="usb", ATTRS{idVendor}=="28de", MODE="0666"

    # This rule is necessary for gamepad emulation; make sure you replace 'pgriffais' with a group that the user that runs Steam belongs to
    KERNEL=="uinput", MODE="0660", GROUP="games", OPTIONS+="static_node=uinput"

    # Valve HID devices over USB hidraw
    KERNEL=="hidraw*", ATTRS{idVendor}=="28de", MODE="0666"

    # Valve HID devices over bluetooth hidraw
    KERNEL=="hidraw*", KERNELS=="*28DE:*", MODE="0666"

    # DualShock 4 over USB hidraw
    KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="05c4", MODE="0666"

    # DualShock 4 wireless adapter over USB hidraw
    KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ba0", MODE="0666"

    # DualShock 4 Slim over USB hidraw
    KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="09cc", MODE="0666"

    # DualShock 4 over bluetooth hidraw
    KERNEL=="hidraw*", KERNELS=="*054C:05C4*", MODE="0666"

    # DualShock 4 Slim over bluetooth hidraw
    KERNEL=="hidraw*", KERNELS=="*054C:09CC*", MODE="0666"

    # Nintendo Switch Pro Controller over USB hidraw
    KERNEL=="hidraw*", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="2009", MODE="0666"

    # Nintendo Switch Pro Controller over bluetooth hidraw
    KERNEL=="hidraw*", KERNELS=="*057E:2009*", MODE="0666"
  '';

  # Virtualization
  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;

  # Enable CUPS
  services.printing.enable = true;
  services.avahi.enable = true;
  services.avahi.nssmdns = true;

  # Security
  services.gnome.gnome-keyring.enable = true;
  services.udev.packages = [ pkgs.yubikey-personalization ];
  environment.shellInit = ''
    export GPG_TTY="$(tty)"
    gpg-connect-agent /bye
    export SSH_AUTH_SOCKET="/run/user/$UID/gnupg/S.gpg-agent.ssh"
  '';

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Sound
  sound.enable = false;
  hardware.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

  # Network Configuration
  security.rtkit.enable = true;
  services.dnsmasq.enable = true;

  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "dnsmasq";

  # Keyboard & Input

  i18n.inputMethod = {
    enabled = "fcitx5";
    fcitx5.addons = with pkgs; [ fcitx5-mozc ];
  };

  i18n.defaultLocale = "ja_JP.UTF-8";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "ja_JP.UTF-8/UTF-8" ];

  # Graphics

  services.xserver.enable = true;
  hardware.opengl.driSupport32Bit = true;
  hardware.opengl.enable = true;

  # Fonts
  fonts.fonts = with pkgs; [
    noto-fonts
    noto-fonts-cjk
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-emoji
    ipaexfont
    hanazono
    migu
  ];
  fonts.fontDir.enable = true;

  # Applications & Services
  services.fwupd.enable = true;
  services.flatpak.enable = true;
  programs.dconf.enable = true;

  xdg = {
    portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-kde
        xdg-desktop-portal-gtk
      ];
      gtkUsePortal = true;
    };
  };

  programs.adb.enable = true;

  environment.variables.EDITOR = "nvim";
  environment.systemPackages = with pkgs; [
    alacritty
    neofetch
    git
    neovim
    lm_sensors
    fwupd-efi
    wayland
    nwg-drawer
    eww-wayland
    wlr-randr
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

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  services.dbus.enable = true;

  # Users
  users.groups.games = {};

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
    home.file."Pictures/wallpaper.jpg".source = ./pictures/wallpaper.jpg;
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
