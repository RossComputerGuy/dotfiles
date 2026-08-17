{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Each *arr application, the port it answers on, and the port its exporter
  # answers on. exportarr defaults to 9708 for every one of them, and four
  # cannot share a port, so they are numbered from there.
  #
  # keyFile is the config.xml the application writes. It holds the API key that
  # the application made for itself, so nothing here has to be chosen or kept.
  arrs = {
    sonarr = {
      port = config.services.sonarr.settings.server.port;
      exporterPort = 9709;
      keyFile = "${config.services.sonarr.dataDir}/config.xml";
    };
    radarr = {
      port = config.services.radarr.settings.server.port;
      exporterPort = 9710;
      keyFile = "${config.services.radarr.dataDir}/config.xml";
    };
    lidarr = {
      port = config.services.lidarr.settings.server.port;
      exporterPort = 9711;
      keyFile = "${config.services.lidarr.dataDir}/config.xml";
    };
    prowlarr = {
      port = config.services.prowlarr.settings.server.port;
      exporterPort = 9712;
      keyFile = "${config.services.prowlarr.dataDir}/config.xml";
    };
  };
in
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
    "d /var/lib/media/music 2775 lidarr media -"
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

  # The same for music. Lidarr leans on MusicBrainz for its metadata, and that
  # service goes down more often than the ones Sonarr and Radarr use, so a
  # search that finds nothing is worth checking against MusicBrainz before
  # looking for a fault here.
  services.lidarr = {
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

  # One exporter for each *arr, so the queue, the missing episodes and the
  # health checks each application already runs show up on a dashboard instead
  # of in four separate web interfaces.
  services.prometheus.exporters = lib.mapAttrs' (
    name: arr:
    lib.nameValuePair "exportarr-${name}" {
      enable = true;
      port = arr.exporterPort;
      listenAddress = "127.0.0.1";
      url = "http://127.0.0.1:${toString arr.port}";
      # systemd reads this as root with LoadCredential= before the exporter
      # starts, so the file below never has to be readable by anybody else.
      apiKeyFile = "/run/exportarr-${name}/api-key";
    }
  ) arrs;

  # Take each API key out of the configuration the application wrote. Nothing
  # is chosen by hand and nothing is stored twice, so a key that an application
  # makes again is picked up by restarting this unit.
  #
  # OpenBao is the wrong home for these. It holds what a person decided. These
  # are made by the application, they live in its own state directory already,
  # and a copy in OpenBao would only be a second thing to keep in step.
  systemd.services = lib.mkMerge [
    {
      qbittorrent.vpnConfinement = {
        enable = true;
        vpnNamespace = "mullvad";
      };
    }

    (lib.mapAttrs' (
      name: arr:
      lib.nameValuePair "exportarr-${name}-key" {
      description = "Publish ${name}'s API key where its exporter can read it";
      requiredBy = [ "prometheus-exportarr-${name}-exporter.service" ];
      before = [ "prometheus-exportarr-${name}-exporter.service" ];
      # The file does not exist until the application has started once.
      after = [ "${name}.service" ];
      wants = [ "${name}.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "exportarr-${name}";
        RuntimeDirectoryMode = "0700";
        RuntimeDirectoryPreserve = "yes";
        # A first boot reaches this before the application has written its
        # configuration. Keep trying rather than leaving the exporter down
        # until somebody notices.
        Restart = "on-failure";
        RestartSec = "30s";
        ExecStart = pkgs.writeShellScript "exportarr-${name}-key" ''
          set -o pipefail

          if [ ! -r ${arr.keyFile} ]; then
            echo "${arr.keyFile} is not there yet. ${name} writes it on its first start." >&2
            exit 1
          fi

          key=$(${lib.getExe pkgs.gnused} -n 's:.*<ApiKey>\(.*\)</ApiKey>.*:\1:p' ${arr.keyFile})

          if [ -z "$key" ]; then
            echo "No ApiKey element in ${arr.keyFile}." >&2
            exit 1
          fi

          ${lib.getExe' pkgs.coreutils "install"} -m 0400 /dev/null /run/exportarr-${name}/api-key
          ${lib.getExe' pkgs.coreutils "printf"} '%s' "$key" > /run/exportarr-${name}/api-key
        '';
      };
        unitConfig.StartLimitIntervalSec = 0;
      }
    ) arrs)
  ];

  # The scrape job lives here rather than in monitoring.nix, because
  # scrapeConfigs is a list and NixOS joins the definitions. So the exporters
  # and the job that reads them stay in one file.
  services.prometheus.scrapeConfigs = [
    {
      job_name = "arr";
      static_configs = lib.mapAttrsToList (name: arr: {
        targets = [ "127.0.0.1:${toString arr.exporterPort}" ];
        labels.instance = name;
      }) arrs;
    }
  ];

  # No port is open here. Caddy reaches each of these on the loopback and
  # publishes them as names. See web.nix and service-ports.nix.
}
