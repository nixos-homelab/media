# rTorrent's rows: one on the Media dashboard, one on the Workload dashboard for its namespace
{ inputs, ... }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  cfg = config.homelab.rtorrent;
  j = ''job="rtorrent"'';
  rows = {
    overview = g.row { title = "rTorrent"; } (
      g.autoGrid { columns = 3; } [
        (g.timeseries {
          title = "Traffic";
          unit = "Bps";
          description = "Downloaded above the line, uploaded below";
          queries = [
            (g.prom "rate(rtorrent_downloaded_bytes_total{${j}}[$__rate_interval])" { legend = "down"; })
            (g.prom "-rate(rtorrent_uploaded_bytes_total{${j}}[$__rate_interval])" { legend = "up"; })
          ];
        })
        (g.stat {
          title = "Torrents";
          decimals = 0;
          queries = [
            (g.prom ''sum by (view) (rtorrent_torrents_total{${j}, view=~"started|seeding|leeching|stopped"})''
              {
                instant = true;
                legend = "{{view}}";
              }
            )
          ];
        })
        (g.stat {
          title = "Up";
          queries = [ (g.prom "rtorrent_up{${j}}" { instant = true; }) ];
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
        })
      ]
    );
    drilldown = g.row { title = "rTorrent"; } (
      g.autoGrid { columns = 1; } [
        (g.table {
          title = "Torrents by label and view";
          queries = [ (g.prom "rtorrent_torrents_total{${j}}" { instant = true; }) ];
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
  config = lib.mkIf cfg.grafana.enable {
    homelab.grafana.overviews.media = {
      title = "Media";
      description = "The media stack: what's missing, downloading, streaming, and the apps' health";
      rows.rtorrent = {
        order = 650;
        row = rows.overview;
      };
    };
    homelab.grafana.drilldown.rows.rtorrent = {
      workload = "rtorrent";
      row = rows.drilldown;
    };
  };
}
