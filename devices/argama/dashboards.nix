{
  lib,
  pkgs,
  ...
}:
let
  # Every dashboard names the Prometheus datasource by this identifier, so
  # monitoring.nix gives the provisioned datasource the same one. Without a
  # fixed identifier Grafana invents one at first start, and a dashboard written
  # ahead of time cannot name it.
  datasource = {
    type = "prometheus";
    uid = "prometheus";
  };

  # Grafana wants a pixel position on every panel. Writing those by hand turns
  # a one line change into a renumbering of the whole file, so lay them out
  # here instead. A dashboard is a list of panels, each of them 24 columns wide
  # at most, and they flow left to right and then down.
  layout =
    panels:
    let
      step =
        acc: panel:
        let
          w = panel.w or 12;
          h = panel.h or 8;
          # Start a new line when this panel does not fit on the current one.
          wraps = acc.x + w > 24;
          x = if wraps then 0 else acc.x;
          y = if wraps then acc.y + acc.rowHeight else acc.y;
        in
        {
          # Where the next panel starts, and how tall the line is so far.
          x = x + w;
          inherit y;
          rowHeight = if wraps then h else lib.max acc.rowHeight h;
          out = acc.out ++ [
            (removeAttrs panel [ "w" "h" ]
            // {
              gridPos = {
                inherit
                  h
                  w
                  x
                  y
                  ;
              };
            })
          ];
        };
    in
    (lib.foldl' step {
      x = 0;
      y = 0;
      rowHeight = 0;
      out = [ ];
    } panels).out;

  # A time series panel. `expr` is one query or a list of them, and `legend`
  # names the series with Grafana's own label syntax.
  graph =
    {
      title,
      expr,
      legend ? "{{instance}}",
      unit ? "short",
      w ? 12,
      h ? 8,
      min ? 0,
      max ? null,
      description ? "",
    }:
    {
      inherit
        title
        w
        h
        description
        ;
      type = "timeseries";
      inherit datasource;
      targets = lib.imap0 (i: e: {
        expr = e;
        legendFormat = legend;
        refId = builtins.elemAt lib.strings.upperChars i;
      }) (lib.toList expr);
      fieldConfig = {
        defaults = {
          inherit unit min;
          custom.fillOpacity = 10;
          custom.lineWidth = 2;
        }
        // lib.optionalAttrs (max != null) { inherit max; };
        overrides = [ ];
      };
    };

  # A single number with a colour behind it. Use it for the things you want to
  # read without thinking: how many machines are up, how many units failed.
  stat =
    {
      title,
      expr,
      legend ? "{{instance}}",
      unit ? "short",
      w ? 6,
      h ? 5,
      # Each entry is a colour and the value at which it starts. The first has
      # no value, because it covers everything below the second.
      steps ? [
        { color = "green"; }
      ],
      # Turn a number into a word. Each entry gives a value, the text to show
      # and the colour. A code like 2 says nothing on its own, FAULTED does.
      mappings ? [ ],
      description ? "",
      text ? "auto",
    }:
    {
      inherit
        title
        w
        h
        description
        ;
      type = "stat";
      inherit datasource;
      targets = [
        {
          inherit expr;
          legendFormat = legend;
          refId = "A";
          # Read the value at this moment and not across the whole window. A
          # range query keeps every series the window ever held, so a series
          # that stopped, because a label changed or a target went away, holds
          # its last value on the panel for as long as the window is wide. That
          # made a pool which recovered hours ago still read DEGRADED, and it
          # showed every disk twice.
          instant = true;
        }
      ];
      options = {
        colorMode = "background";
        graphMode = "none";
        textMode = text;
        reduceOptions.calcs = [ "lastNotNull" ];
      };
      fieldConfig = {
        defaults = {
          inherit unit;
          thresholds = {
            mode = "absolute";
            inherit steps;
          };
        }
        // lib.optionalAttrs (mappings != [ ]) {
          mappings = [
            {
              type = "value";
              options = lib.listToAttrs (
                lib.imap0 (
                  index: m:
                  lib.nameValuePair (toString m.value) {
                    inherit index;
                    inherit (m) text color;
                  }
                ) mappings
              );
            }
          ];
        };
        overrides = [ ];
      };
    };

  # ZFS reports health as a number. The exporter counts from zero with iota, so
  # these are the codes in order. See collector/transform.go in pdf/zfs_exporter.
  poolHealth = [
    {
      value = 0;
      text = "ONLINE";
      color = "green";
    }
    {
      value = 1;
      text = "DEGRADED";
      color = "orange";
    }
    {
      value = 2;
      text = "FAULTED";
      color = "red";
    }
    {
      value = 3;
      text = "OFFLINE";
      color = "red";
    }
    {
      value = 4;
      text = "UNAVAIL";
      color = "red";
    }
    {
      value = 5;
      text = "REMOVED";
      color = "red";
    }
    {
      value = 6;
      text = "SUSPENDED";
      color = "red";
    }
  ];

  # A table, for anything that is a list rather than a line.
  table =
    {
      title,
      expr,
      w ? 24,
      h ? 8,
      description ? "",
    }:
    {
      inherit
        title
        w
        h
        description
        ;
      type = "table";
      inherit datasource;
      targets = [
        {
          inherit expr;
          refId = "A";
          format = "table";
          instant = true;
        }
      ];
      fieldConfig = {
        defaults = { };
        overrides = [ ];
      };
    };

  mkDashboard =
    {
      uid,
      title,
      description ? "",
      refresh ? "30s",
      from ? "now-6h",
      panels,
    }:
    {
      inherit
        uid
        title
        description
        refresh
        ;
      schemaVersion = 39;
      editable = true;
      time = {
        inherit from;
        to = "now";
      };
      timezone = "browser";
      panels = layout panels;
    };

  dashboards = {
    # Read this one first. It answers "is anything wrong" for the whole fleet.
    fleet = mkDashboard {
      uid = "fleet";
      title = "Fleet";
      description = "Every machine argama scrapes, and whether it is healthy.";
      panels = [
        (stat {
          title = "Machines up";
          description = "hizack-b is a laptop and reads as down whenever it is away.";
          expr = ''sum(up{job="node"})'';
          w = 6;
          steps = [
            { color = "red"; }
            {
              color = "green";
              value = 2;
            }
          ];
        })
        (stat {
          title = "Failed units";
          description = "Any systemd unit in the failed state, on any machine.";
          expr = ''sum(node_systemd_unit_state{state="failed"})'';
          w = 6;
          steps = [
            { color = "green"; }
            {
              color = "red";
              value = 1;
            }
          ];
        })
        (stat {
          title = "Scrape targets down";
          description = "Counts exporters and not machines, so one dead exporter shows here.";
          expr = "sum(up == 0)";
          w = 6;
          steps = [
            { color = "green"; }
            {
              color = "red";
              value = 1;
            }
          ];
        })
        (stat {
          title = "Oldest boot";
          description = "How long the machine that has been up longest has been up.";
          expr = "max(time() - node_boot_time_seconds)";
          unit = "s";
          w = 6;
          steps = [
            { color = "blue"; }
          ];
        })

        (table {
          title = "Units in the failed state";
          description = "Empty is the healthy answer.";
          expr = ''node_systemd_unit_state{state="failed"} == 1'';
        })

        (graph {
          title = "CPU in use";
          description = "All cores together, so 100 percent means the machine is full.";
          expr = ''100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'';
          unit = "percent";
          max = 100;
        })
        (graph {
          title = "Memory in use";
          expr = ''
            100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)'';
          unit = "percent";
          max = 100;
        })

        (graph {
          title = "Load, one minute";
          description = "Compare against the core count. argama has 64.";
          expr = "node_load1";
        })
        (graph {
          title = "Root filesystem used";
          expr = ''
            100 * (1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})'';
          unit = "percent";
          max = 100;
        })

        (graph {
          title = "Network in";
          expr = ''rate(node_network_receive_bytes_total{device!~"lo|veth.*"}[5m])'';
          legend = "{{instance}} {{device}}";
          unit = "Bps";
        })
        (graph {
          title = "Network out";
          expr = ''rate(node_network_transmit_bytes_total{device!~"lo|veth.*"}[5m])'';
          legend = "{{instance}} {{device}}";
          unit = "Bps";
        })
      ];
    };

    # The pools hold the media, the fleet's backups and the OpenBao data, so
    # this is the dashboard that matters most when a disk starts to go.
    storage = mkDashboard {
      uid = "storage";
      title = "Storage";
      description = "ZFS pools and datasets, and the health of the disks under them.";
      panels = [
        (stat {
          title = "Pool health";
          description = "ONLINE is the only good answer. Anything else needs zpool status.";
          expr = "zfs_pool_health";
          legend = "{{pool}}";
          w = 8;
          text = "value_and_name";
          mappings = poolHealth;
          steps = [
            { color = "green"; }
            {
              color = "red";
              value = 1;
            }
          ];
        })
        (stat {
          title = "SMART self assessment";
          description = "1 means the disk says it passed. 0 means replace it.";
          expr = "smartctl_device_smart_status";
          legend = "{{device}}";
          w = 8;
          text = "value_and_name";
          mappings = [
            {
              value = 0;
              text = "FAILED";
              color = "red";
            }
            {
              value = 1;
              text = "PASSED";
              color = "green";
            }
          ];
          steps = [
            { color = "red"; }
            {
              color = "green";
              value = 1;
            }
          ];
        })
        (stat {
          title = "Flash worn";
          description = "The share of the write life an NVMe drive has spent. 100 is the end of the warranty and not the end of the disk.";
          expr = "max(smartctl_device_percentage_used)";
          unit = "percent";
          w = 8;
          steps = [
            { color = "green"; }
            {
              color = "orange";
              value = 80;
            }
            {
              color = "red";
              value = 95;
            }
          ];
        })

        (graph {
          title = "Pool used";
          description = "ZFS slows down and fragments badly above about 80 percent.";
          expr = "100 * zfs_pool_allocated_bytes / zfs_pool_size_bytes";
          legend = "{{pool}}";
          unit = "percent";
          max = 100;
        })
        (graph {
          title = "Pool free";
          expr = "zfs_pool_free_bytes";
          legend = "{{pool}}";
          unit = "bytes";
        })

        (graph {
          title = "Fragmentation";
          expr = "zfs_pool_fragmentation_ratio";
          legend = "{{pool}}";
          unit = "percent";
          max = 100;
        })
        (graph {
          title = "Largest datasets";
          description = "The fifteen datasets that hold the most.";
          expr = "topk(15, zfs_dataset_used_bytes)";
          legend = "{{name}}";
          unit = "bytes";
        })

        (graph {
          title = "Disk temperature";
          expr = "smartctl_device_temperature";
          legend = "{{device}} {{temperature_type}}";
          unit = "celsius";
          min = null;
        })
        (graph {
          title = "Disk errors";
          description = "Any line that climbs is a disk on its way out. Flat at zero is healthy.";
          expr = [
            "smartctl_device_media_errors"
            "smartctl_device_num_err_log_entries"
            "smartctl_read_total_uncorrected_errors"
            "smartctl_write_total_uncorrected_errors"
          ];
          legend = "{{__name__}} {{device}}";
        })

        (graph {
          title = "Disk read";
          expr = "rate(smartctl_device_bytes_read[5m])";
          legend = "{{device}}";
          unit = "Bps";
        })
        (graph {
          title = "Disk written";
          expr = "rate(smartctl_device_bytes_written[5m])";
          legend = "{{device}}";
          unit = "Bps";
        })
      ];
    };

    # blocky answers for the whole house on one side and the tailnet on the
    # other, so when it stops, everything looks broken at once.
    dns = mkDashboard {
      uid = "dns";
      title = "DNS";
      description = "blocky, on both resolvers. See dns.nix for which is which.";
      panels = [
        (stat {
          title = "Blocking on";
          expr = "min(blocky_blocking_enabled)";
          w = 6;
          mappings = [
            {
              value = 0;
              text = "OFF";
              color = "orange";
            }
            {
              value = 1;
              text = "ON";
              color = "green";
            }
          ];
          steps = [
            { color = "orange"; }
            {
              color = "green";
              value = 1;
            }
          ];
        })
        (stat {
          title = "Denylist entries";
          expr = "sum(blocky_denylist_cache_entries)";
          w = 6;
          steps = [
            { color = "red"; }
            {
              color = "green";
              value = 1;
            }
          ];
        })
        (stat {
          title = "Cached answers";
          expr = "sum(blocky_cache_entries)";
          w = 6;
          steps = [ { color = "blue"; } ];
        })
        (stat {
          title = "Since the lists refreshed";
          description = "blocky refreshes its lists on a timer. A number that keeps growing means the refresh is failing.";
          expr = "time() - max(blocky_last_list_group_refresh_timestamp_seconds)";
          unit = "s";
          w = 6;
          steps = [
            { color = "green"; }
            {
              color = "orange";
              value = 172800;
            }
          ];
        })

        (graph {
          title = "Queries";
          expr = "sum by (instance) (rate(blocky_query_total[5m]))";
          unit = "reqps";
        })
        (graph {
          title = "Answers by kind";
          description = "BLOCKED against CACHED against RESOLVED.";
          expr = "sum by (response_type) (rate(blocky_response_total[5m]))";
          legend = "{{response_type}}";
          unit = "reqps";
        })

        (graph {
          title = "Cache hit share";
          expr = ''
            100 * sum(rate(blocky_cache_hits_total[5m]))
              / clamp_min(sum(rate(blocky_cache_hits_total[5m])) + sum(rate(blocky_cache_misses_total[5m])), 1)'';
          legend = "hits";
          unit = "percent";
          max = 100;
        })
        (graph {
          title = "Answer time, 95th percentile";
          expr = ''
            histogram_quantile(0.95, sum by (le, instance) (rate(blocky_request_duration_seconds_bucket[5m])))'';
          unit = "s";
        })

        (graph {
          title = "Errors";
          description = "Query errors on the left, list downloads that failed on the right. Both should sit at zero.";
          expr = [
            "sum by (instance) (rate(blocky_error_total[5m]))"
            "sum by (instance) (rate(blocky_failed_downloads_total[5m]))"
          ];
          legend = "{{instance}}";
          w = 24;
        })
      ];
    };

    # A backup that fails is quiet, and an expired host certificate takes a
    # machine away from every client at once. Both belong on one screen.
    backups = mkDashboard {
      uid = "backups";
      title = "Backups and certificates";
      description = "What the fleet pushes to argama, and how long the SSH host certificates have left.";
      from = "now-7d";
      panels = [
        (stat {
          title = "Days on the shortest certificate";
          description = "ssh-host-cert.service renews daily against 30 days. Below 7 means renewal has been failing for three weeks.";
          expr = "min((ssh_host_cert_not_after - time()) / 86400)";
          unit = "d";
          w = 8;
          steps = [
            { color = "red"; }
            {
              color = "orange";
              value = 7;
            }
            {
              color = "green";
              value = 14;
            }
          ];
        })
        (stat {
          title = "Repositories written today";
          description = "Counts the repositories that took a write in the last day.";
          expr = ''count(count by (repo) (increase(rest_server_blob_write_total[24h]) > 0)) or vector(0)'';
          w = 8;
          steps = [
            { color = "red"; }
            {
              color = "green";
              value = 1;
            }
          ];
        })
        (stat {
          title = "Received in the last day";
          expr = ''sum(increase(rest_server_blob_write_bytes_total[24h])) or vector(0)'';
          unit = "bytes";
          w = 8;
          steps = [ { color = "blue"; } ];
        })

        (graph {
          title = "Days left on each host certificate";
          expr = "(ssh_host_cert_not_after - time()) / 86400";
          unit = "d";
          w = 24;
        })

        (graph {
          title = "Written to the backup server";
          expr = "rate(rest_server_blob_write_bytes_total[30m])";
          legend = "{{repo}} {{type}}";
          unit = "Bps";
        })
        (graph {
          title = "Read from the backup server";
          description = "A restore, or a check. Ordinary backups read very little.";
          expr = "rate(rest_server_blob_read_bytes_total[30m])";
          legend = "{{repo}} {{type}}";
          unit = "Bps";
        })

        (graph {
          title = "Blobs deleted";
          description = "The server is append only, so a client cannot cause this. Only the weekly restic-prune units on argama can.";
          expr = "rate(rest_server_blob_delete_total[30m])";
          legend = "{{repo}}";
          w = 24;
        })
      ];
    };

    # The things a person uses by name. OpenBao is here because every one of
    # them stops when it seals, so its state belongs on the same screen.
    services = mkDashboard {
      uid = "services";
      title = "Services";
      description = "OpenBao, Caddy, Forgejo and Hydra.";
      panels = [
        (stat {
          title = "OpenBao";
          description = "Sealed means every machine stops reading secrets. It seals at every boot and waits for argama-unseal.";
          expr = "vault_core_unsealed";
          w = 6;
          mappings = [
            {
              value = 0;
              text = "SEALED";
              color = "red";
            }
            {
              value = 1;
              text = "UNSEALED";
              color = "green";
            }
          ];
          steps = [
            { color = "red"; }
            {
              color = "green";
              value = 1;
            }
          ];
        })
        (stat {
          title = "Leases outstanding";
          description = "Every AppRole login makes one. A number that only climbs means something is authenticating and never stopping.";
          expr = "vault_expire_num_leases";
          w = 6;
          steps = [ { color = "blue"; } ];
        })
        (stat {
          title = "Repositories";
          expr = "gitea_repositories";
          w = 6;
          steps = [ { color = "blue"; } ];
        })
        (stat {
          title = "Mirrors";
          description = "Repositories that pull from GitHub on a timer.";
          expr = "gitea_mirrors";
          w = 6;
          steps = [ { color = "blue"; } ];
        })

        (graph {
          title = "Requests through Caddy";
          description = "Every name in the zone arrives here first, so this is the traffic of the whole machine.";
          expr = "sum by (handler) (rate(caddy_http_requests_total[5m]))";
          legend = "{{handler}}";
          unit = "reqps";
        })
        (graph {
          title = "Answers by code";
          description = "A step in 5xx is the first sign a service behind Caddy has fallen over.";
          expr = "sum by (code) (rate(caddy_http_response_duration_seconds_count[5m]))";
          legend = "{{code}}";
          unit = "reqps";
        })

        (graph {
          title = "Caddy answer time, 95th percentile";
          expr = ''
            histogram_quantile(0.95, sum by (le, handler) (rate(caddy_http_response_duration_seconds_bucket[5m])))'';
          legend = "{{handler}}";
          unit = "s";
        })
        (graph {
          title = "Requests in flight";
          description = "Requests Caddy is still working on. A number that stays high means something behind it is slow.";
          expr = "sum by (handler) (caddy_http_requests_in_flight)";
          legend = "{{handler}}";
        })

        (graph {
          title = "Forgejo contents";
          expr = [
            "gitea_repositories"
            "gitea_users"
            "gitea_issues_open"
            "gitea_releases"
            "gitea_webhooks"
          ];
          legend = "{{__name__}}";
        })
        (graph {
          title = "Hydra requests";
          description = "Hydra publishes request counters and nothing about the build queue, so read this as a sign of life.";
          expr = ''sum by (code) (rate(http_requests_total{job="hydra"}[5m]))'';
          legend = "{{code}}";
          unit = "reqps";
        })

        (graph {
          title = "OpenBao requests";
          expr = "rate(vault_core_handle_request_count[5m])";
          legend = "requests";
          unit = "reqps";
        })
        (graph {
          title = "OpenBao memory";
          expr = "vault_runtime_alloc_bytes";
          legend = "allocated";
          unit = "bytes";
        })
      ];
    };

    # The download stack. Every metric name here starts with the application's
    # own name, so a panel that covers all four matches on __name__.
    media = mkDashboard {
      uid = "media";
      title = "Media";
      description = "Sonarr, Radarr, Lidarr and Prowlarr, through exportarr.";
      panels = [
        (stat {
          title = "Applications answering";
          description = "exportarr asks each application for its status. A zero means that one is down or its API key went stale.";
          expr = ''sum({__name__=~"(sonarr|radarr|lidarr|prowlarr)_system_status"})'';
          w = 8;
          steps = [
            { color = "red"; }
            {
              color = "orange";
              value = 1;
            }
            {
              color = "green";
              value = 4;
            }
          ];
        })
        (stat {
          title = "Health issues";
          description = "What each application reports on its own health page. Zero is the healthy answer.";
          expr = ''sum({__name__=~"(sonarr|radarr|lidarr|prowlarr)_system_health_issues"}) or vector(0)'';
          w = 8;
          steps = [
            { color = "green"; }
            {
              color = "orange";
              value = 1;
            }
          ];
        })
        (stat {
          title = "Free on the library";
          expr = ''max({__name__=~"(sonarr|radarr|lidarr)_diskspace_free_bytes"})'';
          unit = "bytes";
          w = 8;
          steps = [
            { color = "red"; }
            {
              color = "orange";
              value = 107374182400;
            }
            {
              color = "green";
              value = 536870912000;
            }
          ];
        })

        (table {
          title = "Health issues in detail";
          description = "Empty is the healthy answer. The message column says what each application wants.";
          expr = ''{__name__=~"(sonarr|radarr|lidarr|prowlarr)_system_health_issues"} > 0'';
        })

        (graph {
          title = "Queue";
          description = "Items waiting or downloading, per application. A line that never falls is a stuck download.";
          expr = ''sum by (instance) ({__name__=~"(sonarr|radarr|lidarr)_queue_total"})'';
        })
        (graph {
          title = "Queue by state";
          expr = ''sum by (instance, download_state) ({__name__=~"(sonarr|radarr|lidarr)_queue_total"})'';
          legend = "{{instance}} {{download_state}}";
        })

        (graph {
          title = "Series and episodes";
          expr = [
            "sonarr_series_total"
            "sonarr_episode_total"
            "sonarr_episode_downloaded_total"
          ];
          legend = "{{__name__}}";
        })
        (graph {
          title = "Episodes still wanted";
          description = "Missing means monitored and never downloaded. Cutoff unmet means it is there but below the quality you asked for.";
          expr = [
            "sonarr_episode_missing_total"
            "sonarr_episode_cutoff_unmet_total"
          ];
          legend = "{{__name__}}";
        })

        (graph {
          title = "Library size";
          expr = ''{__name__=~"(sonarr|radarr|lidarr)_.*_filesize_bytes"}'';
          legend = "{{__name__}}";
          unit = "bytes";
          w = 24;
        })
      ];
    };
  };
in
{
  # One file for each dashboard, and one provider that reads the directory.
  # Grafana rereads them on the interval below, so a rebuild is enough and the
  # service does not have to restart.
  environment.etc = lib.mapAttrs' (
    name: value:
    lib.nameValuePair "grafana/dashboards/${name}.json" {
      source = pkgs.writeText "grafana-dashboard-${name}.json" (builtins.toJSON value);
    }
  ) dashboards;

  services.grafana.provision.dashboards.settings.providers = [
    {
      name = "argama";
      options.path = "/etc/grafana/dashboards";
      # The files are read only, so let Grafana say so in its interface rather
      # than letting somebody edit a panel that the next rebuild undoes.
      options.foldersFromFilesStructure = false;
      allowUiUpdates = false;
      updateIntervalSeconds = 60;
    }
  ];
}
