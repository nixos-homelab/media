# rTorrent's panels on the Media dashboard, and its row on the Workload dashboard
# Its namespace counts toward the `media` area of the Home dashboard, whose CPU, memory and traffic graphs sum the
# containers by area
{ inputs, ... }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  cfg = config.homelab.rtorrent;
  j = ''job="rtorrent"'';
  rows = {
    drilldown = g.row { title = "rTorrent"; } (
      g.autoGrid { columns = 1; } [
        (g.table {
          title = "Torrents by label and view";
          queries = [ (g.prom "max by (label, view) (rtorrent_torrents_total{${j}})" { instant = true; }) ];
        })
      ]
    );
  };
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.grafana ];
  options.homelab.rtorrent.grafana.enable = lib.mkOption {
    description = "Whether the Media and Workload dashboards have rTorrent's rows.";
    type = lib.types.bool;
    default =
      cfg.enable && cfg.metrics.enable && config.homelab.alloy.enable && config.homelab.grafana.enable;
    defaultText = lib.literalExpression ''
      config.homelab.rtorrent.enable && config.homelab.rtorrent.metrics.enable && config.homelab.alloy.enable
      && config.homelab.grafana.enable
    '';
  };
  config = lib.mkMerge [
    {
      homelab.grafana.home.areas.media = {
        color = "#b877d9";
        namespaces = lib.mkIf config.homelab.rtorrent.enable [ "rtorrent" ];
      };
    }
    (lib.mkIf cfg.grafana.enable {
      homelab.grafana.overviews.media = {
        title = "Media";
        description = "The media stack: what's missing, downloading, streaming, and the apps' health";
        panels = {
          rtorrent-up = {
            order = 16;
            w = 3;
            h = 4;
            panel = g.stat {
              title = "rTorrent";
              description = "Whether the exporter reaches rTorrent, and the torrents it seeds";
              queries = [ (g.prom "rtorrent_up{${j}}" { }) ];
              mappings = [
                {
                  type = "value";
                  options = {
                    "0" = {
                      text = "Down";
                      color = "red";
                    };
                    "1" = {
                      text = "Up";
                      color = "green";
                    };
                  };
                }
              ];
            };
          };
          rtorrent-traffic = {
            order = 140;
            w = 8;
            h = 8;
            panel = g.timeseries {
              title = "rTorrent traffic";
              description = "Downloaded above the line, uploaded (seeding) below";
              unit = "Bps";
              queries = [
                (g.prom "rate(rtorrent_downloaded_bytes_total{${j}}[$__rate_interval])" { legend = "down"; })
                (g.prom "-rate(rtorrent_uploaded_bytes_total{${j}}[$__rate_interval])" { legend = "up"; })
              ];
            };
          };
          rtorrent-torrents = {
            order = 141;
            w = 8;
            h = 8;
            panel = g.timeseries {
              title = "Torrents";
              description = "Torrents by what they're doing, stacked: leeching (downloading), seeding, and stopped";
              decimals = 0;
              custom = {
                stacking.mode = "normal";
                fillOpacity = 50;
              };
              queries = [
                (g.prom ''sum by (view) (rtorrent_torrents_total{${j}, view=~"seeding|leeching|stopped"})'' {
                  legend = "{{view}}";
                })
              ];
            };
          };
        };
      };
      homelab.grafana.drilldown.rows.rtorrent = {
        workload = "rtorrent";
        row = rows.drilldown;
      };
    })
  ];
}
