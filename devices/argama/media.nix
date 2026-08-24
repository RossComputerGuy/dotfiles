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

  # Where /etc/resolv.conf really ends up. NixOS makes it a symlink to
  # /etc/static/resolv.conf, and that one points here.
  resolvConf = config.environment.etc."resolv.conf".source;
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

        # No password is set here, and qBittorrent answers that by making a new
        # random one at every start and writing it to the journal. So every
        # restart broke the *arr applications, which had the old one.
        #
        # Take the credential away instead of trying to keep one in step. Only
        # two things can reach this port. Caddy proxies to the namespace address
        # from the bridge, and service-ports.nix gives qbit auth = "forward", so
        # that path has already been through Authelia. The *arr applications
        # reach it from the same bridge. Nothing else can: 8080 is open on no
        # interface.
        AuthSubnetWhitelistEnabled = true;
        AuthSubnetWhitelist = lib.concatStringsSep "," [
          "${config.vpnNamespaces.mullvad.bridgeAddress}/32"
          "${config.vpnNamespaces.mullvad.namespaceAddress}/32"
        ];
      };
      BitTorrent.Session = {
        DefaultSavePath = "/var/lib/media/downloads";
        TempPathEnabled = false;

        # Bind to the tunnel. libtorrent reads the routing table before it
        # announces, and it skips a tracker that the bound address cannot
        # reach. The namespace holds two addresses. The veth address
        # 192.168.15.1 reaches only the host, so every announce failed with
        # "skipping tracker announce (unreachable)". This address is on
        # mullvad0, which holds the default route.
        #
        # The module writes this file again at each start, so a value that a
        # person sets in the WebUI is lost at the next restart. The value must
        # be here.
        #
        # Mullvad gives this address with the WireGuard key. A new key gives a
        # different address, and then qBittorrent binds to nothing and stops
        # without a message. If that happens, read the new address from
        # "ip netns exec mullvad ip -brief addr show mullvad0".
        InterfaceAddress = "10.68.222.190";
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

      # The last link in the chain that a sealed OpenBao breaks. The sidecar
      # upholds mullvad-key, mullvad-key upholds mullvad, and without this
      # mullvad upholds nothing, so qbittorrent stays down after every unseal.
      # qbittorrent has BindsTo on mullvad, so it goes down with the tunnel and
      # nothing would start it again. See devices/argama/monitoring.nix.
      #
      # BindsTo is the right relation and stays. qbittorrent must never run
      # outside the namespace, so it has to stop when the tunnel does.
      mullvad.upholds = [ "qbittorrent.service" ];

      # Give qBittorrent the tunnel's resolver.
      #
      # VPN-Confinement already asks for this. Its systemd.nix carries
      #   BindReadOnlyPaths = [ "/etc/netns/mullvad/resolv.conf:/etc/resolv.conf:norbind" ]
      # and the directive does reach the unit, but no such mount appears in
      # /proc/PID/mountinfo. So qBittorrent read argama's own resolv.conf,
      # which names 127.0.0.53. That is the systemd-resolved stub, and it
      # listens in argama's network namespace and not in this one, so every
      # name lookup was refused at once.
      #
      # The tunnel itself was never at fault. A request to an address answered
      # 301 while the same request to a name answered nothing, and DHT kept
      # working the whole time because DHT holds addresses and asks for no
      # names. What broke was only the trackers, which is why 35 torrents sat
      # on "Host not found (non-authoritative), try again later" while the
      # speed slowly fell to zero as the peers DHT had found went away. A
      # restart looked like a cure because it made libtorrent find peers
      # again, and then the same decay started over.
      #
      # /etc/resolv.conf is a symlink to /etc/static/resolv.conf, which points
      # at the file below. Name that file, because a bind mount follows the
      # symlink to it anyway. The mount belongs to this unit alone, so
      # systemd-resolved on argama keeps its own file.
      #
      # This adds to the module's entry rather than replacing it, because
      # NixOS joins lists in serviceConfig. The other entry stays and does
      # nothing, the same as before.
      qbittorrent.serviceConfig.BindReadOnlyPaths = [
        "/etc/netns/mullvad/resolv.conf:${resolvConf}:norbind"
      ];

      # Watch the one thing that breaks. A tracker lookup failing inside the
      # tunnel namespace writes nothing to the journal and fails no unit, so
      # this took three sessions to find. It cost hours of downloads each time
      # while every dashboard read green.
      #
      # Two numbers, both read from qBittorrent's own namespaces:
      #
      #  - Is the tunnel's resolver mounted where the process reads it. Zero
      #    means the trap above came back, which a systemd change can do on
      #    its own with no edit here.
      #  - Does a name resolve. Zero with a working tunnel means the same
      #    fault, whatever caused it.
      #
      # A plain getent cannot answer the second one. This unit keeps AF_UNIX,
      # so nss-resolved answers it from argama's resolver and reports success
      # while qBittorrent, which has no AF_UNIX, gets nothing. Ask the
      # nameserver directly instead and let no name service stand in between.
      qbittorrent-dns-probe = {
        description = "Check that qBittorrent can still resolve a name";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = pkgs.writeShellScript "qbittorrent-dns-probe" ''
            set -o pipefail

            PATH=${
              lib.makeBinPath [
                pkgs.coreutils
                pkgs.dnsutils
                pkgs.gnugrep
                pkgs.systemd
                pkgs.util-linux
              ]
            }

            out=/var/lib/node_exporter/textfile/qbittorrent-dns.prom

            pid=$(systemctl show qbittorrent.service -p MainPID --value)

            {
              echo "# HELP qbittorrent_dns_probe_up Whether this check could run at all."
              echo "# TYPE qbittorrent_dns_probe_up gauge"

              if [ "$pid" = "0" ] || [ ! -d "/proc/$pid" ]; then
                echo "qbittorrent_dns_probe_up 0"
              else
                echo "qbittorrent_dns_probe_up 1"

                # --mount matters. Without it this reads argama's resolv.conf
                # and never sees the fault.
                ns=$(nsenter --mount --net --target "$pid" \
                  grep -m1 '^nameserver' /etc/resolv.conf 2>/dev/null | cut -d' ' -f2)

                echo "# HELP qbittorrent_resolv_mount Whether the tunnel's resolver is the one this process reads."
                echo "# TYPE qbittorrent_resolv_mount gauge"

                # 127.0.0.53 is argama's stub, which listens in argama's
                # namespace and not in this one. Any other address means the
                # bind mount landed.
                if [ -n "$ns" ] && [ "$ns" != "127.0.0.53" ]; then
                  echo "qbittorrent_resolv_mount 1"
                else
                  echo "qbittorrent_resolv_mount 0"
                fi

                echo "# HELP qbittorrent_dns_up Whether a name resolves from inside the tunnel namespace."
                echo "# TYPE qbittorrent_dns_up gauge"

                if [ -z "$ns" ]; then
                  echo "qbittorrent_dns_up 0"
                elif nsenter --mount --net --target "$pid" \
                    dig +short +time=3 +tries=1 "@$ns" example.com > /dev/null 2>&1; then
                  echo "qbittorrent_dns_up 1"
                else
                  echo "qbittorrent_dns_up 0"
                fi
              fi
            } > "$out.new"

            mv "$out.new" "$out"
          '';
        };
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

  # Every two minutes. A name lookup through the tunnel is real traffic to a
  # real resolver, so there is no reason to do it at the scrape interval. The
  # fault lasts for hours once it starts, so two minutes finds it early enough.
  systemd.timers.qbittorrent-dns-probe = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2m";
      OnUnitActiveSec = "2m";
      AccuracySec = "20s";
    };
  };

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
