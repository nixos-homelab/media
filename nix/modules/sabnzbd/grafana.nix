# SABnzbd's rows: one on the Media dashboard, one on the Workload dashboard for its namespace
{ inputs, ... }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  cfg = config.homelab.sabnzbd;
  j = ''job="sabnzbd"'';
  rows = {
    overview = g.row { title = "SABnzbd"; } (
      g.autoGrid { columns = 4; } [
        (g.stat {
          title = "Speed";
          unit = "Bps";
          queries = [ (g.prom "sabnzbd_speed_bps{${j}}" { instant = true; }) ];
        })
        (g.stat {
          title = "Queue";
          decimals = 0;
          queries = [ (g.prom "sabnzbd_queue_length{${j}}" { instant = true; }) ];
        })
        (g.stat {
          title = "Left to download";
          unit = "bytes";
          queries = [ (g.prom "sabnzbd_remaining_bytes{${j}}" { instant = true; }) ];
        })
        (g.stat {
          title = "Paused";
          queries = [ (g.prom "sabnzbd_paused{${j}}" { instant = true; }) ];
          mappings = [
            {
              type = "value";
              options = {
                "0" = {
                  text = "No";
                  color = "green";
                };
                "1" = {
                  text = "Paused";
                  color = "orange";
                };
              };
            }
          ];
        })
      ]
    );
    drilldown = g.row { title = "SABnzbd"; } (
      g.autoGrid { columns = 2; } [
        (g.timeseries {
          title = "Download speed";
          unit = "Bps";
          queries = [ (g.prom "sabnzbd_speed_bps{${j}}" { legend = "speed"; }) ];
        })
        (g.timeseries {
          title = "Queue";
          decimals = 0;
          queries = [ (g.prom "sabnzbd_queue_length{${j}}" { legend = "queue"; }) ];
        })
      ]
    );
  };
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.grafana ];
  options.homelab.sabnzbd.grafana.enable = lib.mkOption {
    description = "Whether the Media and Workload dashboards have SABnzbd's rows.";
    type = lib.types.bool;
    default =
      cfg.enable && cfg.metrics.enable && config.homelab.alloy.enable && config.homelab.grafana.enable;
    defaultText = lib.literalExpression ''
      config.homelab.sabnzbd.enable && config.homelab.sabnzbd.metrics.enable && config.homelab.alloy.enable
      && config.homelab.grafana.enable
    '';
  };
  config = lib.mkIf cfg.grafana.enable {
    homelab.grafana.overviews.media = {
      title = "Media";
      description = "The media stack: what's missing, downloading, streaming, and the apps' health";
      rows.sabnzbd = {
        order = 630;
        row = rows.overview;
      };
    };
    homelab.grafana.drilldown.rows.sabnzbd = {
      workload = "sabnzbd";
      row = rows.drilldown;
    };
  };
}
