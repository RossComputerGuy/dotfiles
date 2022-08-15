{ config, pkgs, home-manager, lib, nur, ... }:
let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-22.05.tar.gz";
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
  nur = import (builtins.fetchTarball {
    url = https://github.com/nix-community/NUR/archive/6600601c83e9404c2dc5a848c4eb65b0beb9f298.zip;
    sha256 = "1xa7cfzjph965a6jlla5s61srflijpz48lzq27m7x0qym5xq9r6q";
  }) {
    inherit pkgs;
  };
in
{
  imports = [
    ./users/desktop.nix
    nur.repos.ilya-fedin.modules.flatpak-fonts
    nur.repos.ilya-fedin.modules.flatpak-icons
  ];

  lib.computer-guy.dbus-sway-environment = dbus-sway-environment;

  # Steam and Solaar udev
  services.udev.extraRules = ''
    ## Steam
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

    ## Solaar
    ACTION != "add", GOTO="solaar_end"
    SUBSYSTEM != "hidraw", GOTO="solaar_end"

    # USB-connected Logitech receivers and devices
    ATTRS{idVendor}=="046d", GOTO="solaar_apply"

    # Lenovo nano receiver
    ATTRS{idVendor}=="17ef", ATTRS{idProduct}=="6042", GOTO="solaar_apply"

    # Bluetooth-connected Logitech devices
    KERNELS == "0005:046D:*", GOTO="solaar_apply"

    GOTO="solaar_end"

    LABEL="solaar_apply"

    # Allow any seated user to access the receiver.
    # uaccess: modern ACL-enabled udev
    # udev-acl: for Ubuntu 12.10 and older
    TAG+="uaccess", TAG+="udev-acl"

    # Grant members of the "plugdev" group access to receiver (useful for SSH users)
    MODE="0660", GROUP="input"

    LABEL="solaar_end"
  '';

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

  # i18n
  i18n.inputMethod = {
    enabled = "fcitx5";
    fcitx5.addons = with pkgs; [ fcitx5-mozc ];
  };

  # Enable CUPS
  services.printing.enable = true;
  services.avahi.enable = true;
  services.avahi.nssmdns = true;

  # Security
  services.gnome.gnome-keyring.enable = true;
  services.udev.packages = [ pkgs.yubikey-personalization ];
  programs.ssh.askPassword = lib.mkForce "";
  environment.shellInit = ''
    export GPG_TTY="$(tty)"
    gpg-connect-agent /bye
    export SSH_AUTH_SOCKET="/run/user/$UID/gnupg/S.gpg-agent.ssh"
  '';

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Graphics
  services.xserver.enable = true;
  hardware.opengl.driSupport32Bit = true;
  hardware.opengl.enable = true;
  fonts.fontDir.enable = true;

  # Display manager
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.displayManager.defaultSession = "sway";

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

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  services.dbus.enable = true;

  # Users
  users.groups.games = {};
}
