{
  config,
  lib,
  pkgs,
  ...
}:
{
  # All of the media services share this group, so they read and write the same
  # library.
  users.groups.media = { };

  # One dataset holds the downloads and the library together. Sonarr and Radarr
  # make a hard link from the download to the library, and a hard link cannot
  # cross a filesystem boundary. A separate downloads dataset would make each
  # import a full copy.
  systemd.tmpfiles.rules = [
    "d /var/lib/media 2775 root media -"
    "d /var/lib/media/downloads 2775 qbittorrent media -"
    "d /var/lib/media/tv 2775 sonarr media -"
    "d /var/lib/media/movies 2775 radarr media -"
  ];

  services.jellyfin = {
    enable = true;
    group = "media";
  };

  services.sonarr = {
    enable = true;
    group = "media";
  };

  services.radarr = {
    enable = true;
    group = "media";
  };

  # Prowlarr speaks to the indexers only, so it needs no access to the library.
  services.prowlarr.enable = true;

  # jellyseerr is now services.seerr in nixpkgs.
  services.seerr = {
    enable = true;
    port = 5055;
  };

  services.qbittorrent = {
    enable = true;
    group = "media";
    webuiPort = 8080;
    torrentingPort = 51413;
    serverConfig = {
      LegalNotice.Accepted = true;
      Preferences.WebUI = {
        # qBittorrent runs in the mullvad namespace, so the WebUI must listen on
        # all of the addresses in that namespace. The port mapping below is the
        # only way in.
        Address = "*";
      };
      BitTorrent.Session = {
        DefaultSavePath = "/var/lib/media/downloads";
        TempPathEnabled = false;
      };
    };
  };

  # Mullvad confinement. qBittorrent gets a network namespace whose only route
  # out is the WireGuard tunnel. If the tunnel stops, the traffic has no other
  # route, so qBittorrent cannot fall back to the real connection.
  vpnNamespaces.mullvad = {
    enable = true;
    # The mullvad-key unit in secrets.nix copies this out of OpenBao into /run.
    # It must not come from this unit's own PrivateTmp: a mount namespace on
    # the mullvad unit stops "ip netns add" reaching the host. See secrets.nix.
    wireguardConfigFile = "/run/mullvad-key/wireguard.conf";
    # The host and the tailnet reach into the namespace through a veth pair.
    accessibleFrom = [
      "127.0.0.1"
      "100.64.0.0/10"
      "192.168.0.0/16"
      "10.0.0.0/8"
    ];
    portMappings = [
      {
        from = 8080;
        to = 8080;
        protocol = "tcp";
      }
    ];
  };

  systemd.services.qbittorrent.vpnConfinement = {
    enable = true;
    vpnNamespace = "mullvad";
  };

  # No port is open here. Caddy reaches each of these on the loopback and
  # publishes them as names. See web.nix and service-ports.nix.
}
