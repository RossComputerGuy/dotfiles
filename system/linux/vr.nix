{ lib, pkgs, ... }:
{
  # WiVRn streams OpenXR to a standalone headset. ALVR is not possible here.
  # The ALVR streamer is a SteamVR driver, and SteamVR runs on x86_64 only, so
  # no machine in this repo with a display can run it.
  #
  # riscv64 gets nothing. The wivrn package declares lib.platforms.linux, which
  # is the generic list and not a promise that riscv64 builds. jegan and
  # mu-gundam both import this file.
  config = lib.mkIf (!pkgs.stdenv.hostPlatform.isRiscV64) {
    services.wivrn = {
      enable = true;

      # The headset connects when no person is at the keyboard.
      autoStart = true;

      # Gives the server cap_sys_nice, which asynchronous reprojection needs.
      # Upstream disables the unit hardening when this is on.
      highPriority = true;

      # The module default is true, and its steam.package is x86_64 only. That
      # default breaks every aarch64 machine here.
      steam.enable = false;

      # Written out so that no person opens 9757 to the local network later.
      # The tailscale0 rule below is the only route in.
      openFirewall = false;

      config = {
        enable = true;

        # WiVRn is an OpenXR runtime and not a desktop mirror. With no
        # application it shows an empty launcher in the headset. wayvr puts the
        # Wayland desktop in the headset. The wlx-overlay-s package became part
        # of wayvr, so wayvr is the only name now.
        #
        # The module also puts this package in environment.systemPackages, so
        # its desktop file shows in the launcher beside other OpenXR
        # applications.
        json.application = [ pkgs.wayvr ];
      };
    };

    # The headset comes in through Tailscale, so the router forwards no port.
    # mDNS does not cross Tailscale, so the client cannot find this machine by
    # itself. Give the client the MagicDNS name one time.
    networking.firewall.interfaces."tailscale0" = {
      allowedTCPPorts = [ 9757 ];
      allowedUDPPorts = [ 9757 ];
    };
  };
}
