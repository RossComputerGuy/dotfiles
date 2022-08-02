# Base Configuration for nixOS

{ config, pkgs, modulesPath ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
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

  # Virtualization
  virtualisation.docker.enable = true;
  virtualisation.libvirtd.enable = true;

  # Enable CUPS
  services.printing.enable = true;
  services.avahi.enable = true;
  services.avahi.nssmdns = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
  };

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

  # Network Configuration
  security.rtkit.enable = true;
  services.dnsmasq.enable = true;

  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "dnsmasq";

  # Keyboard & Input

  i18n.inputMethod = {
    enabled = "ibus";
    ibus.engines = with pkgs.ibus-engines; [ anthy ];
  };

  # Graphics

  services.xserver.enable = true;
  hardware.opengl.driSupport32Bit = true;
  hardware.opengl.enable = true;

  # Applications & Services
  services.fwupd.enable = true;
  services.flatpak.enable = true;

  xdg = {
    portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-kde
        xdg-desktop-portal-gtk
      ];
      gtkUsePortal = true;
    };
  };

  programns.adb.enable = true;

  environment.variables.EDITOR = "nvim";
  environment.systemPackages = with pkgs; [
    neofetch
    git
    neovim
    lm_sensors
    fwupd-efi
    docker-compose
  ];

  # Users
  users.users.ross = {
    isNormalUser = true;
    home = "/home/ross";
    description = "Tristan Ross";
    extraGroups = [ "wheel" "docker" "adbusers" ];
  };
}
