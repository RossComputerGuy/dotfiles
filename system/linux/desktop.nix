{ config, lib, pkgs, ... }:
{
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
  services.printing = {
    enable = true;
    drivers = with pkgs; [ hplipWithPlugin ];
  };
  services.avahi = {
    enable = true;
    nssmdns = true;
    openFirewall = true;
  };

  # Security
  services.gnome.gnome-keyring.enable = true;
  services.udev.packages = [ pkgs.yubikey-personalization ];
  programs.ssh.askPassword = lib.mkForce "";
  environment.shellInit = ''
    export GPG_TTY="$(tty)"
    gpg-connect-agent /bye
    export SSH_AUTH_SOCKET="/run/user/$UID/gnupg/S.gpg-agent.ssh"
  '';

  environment.sessionVariables.XDG_DATA_DIRS = ["/var/lib/flatpak/exports/share"];

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  # Graphics
  services.gnome.at-spi2-core.enable = true;
  services.xserver.enable = true;
  hardware.opengl.enable = true;
  fonts.fontDir.enable = true;

  # Display manager
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.displayManager.defaultSession = "sway";

  services.xserver.windowManager.i3 = {
    enable = true;
    package = pkgs.i3-gaps;
  };

  # Applications & Services
  services.flatpak.enable = true;
  services.upower.enable = true;
  programs.dconf.enable = true;

  xdg = {
    portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-kde
      ] ++ lib.optional (!config.services.xserver.desktopManager.gnome.enable) xdg-desktop-portal-gtk;
    };
  };

  systemd.user.services.polkit-gnome-authentication-agent-1 = {
    description = "polkit-gnome-authentication-agent-1";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
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
