# Plex's rows: one on the Media dashboard, one on the Workload dashboard for its namespace
{ inputs, ... }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  cfg = config.homelab.plex;
  j = ''job="plex"'';
  rows = {
    overview = g.row { title = "Plex"; } (
      g.autoGrid { columns = 3; } [
        (g.timeseries {
          title = "Streaming";
          unit = "bps";
          queries = [
            (g.prom "sum(rate(transmit_bytes_total{${j}}[$__rate_interval])) * 8" { legend = "sent"; })
          ];
        })
        (g.bargauge {
          title = "Library size";
          unit = "bytes";
          queries = [
            (g.prom "library_storage_total{${j}}" {
              instant = true;
              legend = "{{library}}";
            })
          ];
        })
        (g.stat {
          title = "Library length";
          unit = "ms";
          queries = [
            (g.prom "library_duration_total{${j}}" {
              instant = true;
              legend = "{{library}}";
            })
          ];
        })
      ]
    );
    drilldown = g.row { title = "Plex"; } (
      g.autoGrid { columns = 2; } [
        (g.timeseries {
          title = "Sent";
          unit = "bps";
          queries = [
            (g.prom "sum(rate(transmit_bytes_total{${j}}[$__rate_interval])) * 8" { legend = "sent"; })
          ];
        })
        (g.table {
          title = "Server";
          queries = [ (g.prom "server_info{${j}}" { instant = true; }) ];
        })
      ]
    );
  };
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.grafana ];
  options.homelab.plex.grafana.enable = lib.mkOption {
    description = "Whether the Media and Workload dashboards have Plex's rows.";
    type = lib.types.bool;
    default =
      cfg.enable && cfg.metrics.enable && config.homelab.alloy.enable && config.homelab.grafana.enable;
    defaultText = lib.literalExpression ''
      config.homelab.plex.enable && config.homelab.plex.metrics.enable && config.homelab.alloy.enable
      && config.homelab.grafana.enable
    '';
  };
  config = lib.mkIf cfg.grafana.enable {
    homelab.grafana.home.tiles.plex = {
      group = "Media";
      order = 403;
      panel = g.stat {
        title = "Plex streaming";
        unit = "bps";
        links = [
          {
            title = "Media";
            url = "/d/media/media?\${__url_time_range}";
          }
        ];
        queries = [
          (g.prom "sum(rate(transmit_bytes_total{${j}}[$__rate_interval])) * 8" { instant = true; })
        ];
      };
    };
    homelab.grafana.overviews.media = {
      title = "Media";
      description = "The media stack: what's missing, downloading, streaming, and the apps' health";
      rows.plex = {
        order = 640;
        row = rows.overview;
      };
    };
    homelab.grafana.drilldown.rows.plex = {
      workload = "plex";
      row = rows.drilldown;
    };
  };
}
