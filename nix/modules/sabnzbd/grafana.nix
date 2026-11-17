# SABnzbd's panels on the Media dashboard and Home, and its row on the Workload dashboard
{ inputs, ... }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  cfg = config.homelab.sabnzbd;
  j = ''job="sabnzbd"'';
  rows = {
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
    homelab.grafana.home.tiles.sabnzbd = {
      group = "Media";
      order = 402;
      panel = g.stat {
        title = "SABnzbd speed";
        unit = "Bps";
        links = [
          {
            title = "Media";
            url = "/d/media/media?\${__url_time_range}";
          }
        ];
        queries = [ (g.prom "sabnzbd_speed_bps{${j}}" { instant = true; }) ];
      };
    };
    homelab.grafana.overviews.media = {
      title = "Media";
      description = "The media stack: what's missing, downloading, streaming, and the apps' health";
      panels = {
        sabnzbd-state = {
          order = 15;
          w = 3;
          h = 4;
          panel = g.stat {
            title = "SABnzbd";
            description = "What SABnzbd is doing: its download speed, or Paused (orange) when it was paused by hand or for a full disk";
            unit = "Bps";
            queries = [
              (g.prom "sabnzbd_speed_bps{${j}} and on () sabnzbd_paused{${j}} == 0" { legend = "speed"; })
              (g.prom "sabnzbd_paused{${j}} == 1" { legend = "paused"; })
            ];
            overrides = [
              {
                matcher = {
                  id = "byName";
                  options = "paused";
                };
                properties = [
                  {
                    id = "mappings";
                    value = [
                      {
                        type = "value";
                        options."1" = {
                          text = "Paused";
                          color = "orange";
                        };
                      }
                    ];
                  }
                  {
                    id = "unit";
                    value = "none";
                  }
                ];
              }
            ];
            options.textMode = "value";
          };
        };
        sabnzbd-downloads = {
          order = 130;
          w = 8;
          h = 8;
          panel = g.timeseries {
            title = "SABnzbd downloads";
            description = "SABnzbd's download speed, and on the right axis, dashed, the jobs in its queue and the time it estimates for them";
            unit = "Bps";
            queries = [
              (g.prom "sabnzbd_speed_bps{${j}}" { legend = "speed"; })
              (g.prom "sabnzbd_queue_length{${j}}" { legend = "queued jobs"; })
            ];
            overrides = [
              {
                matcher = {
                  id = "byName";
                  options = "queued jobs";
                };
                properties = [
                  {
                    id = "unit";
                    value = "short";
                  }
                  {
                    id = "decimals";
                    value = 0;
                  }
                  {
                    id = "custom.axisPlacement";
                    value = "right";
                  }
                  {
                    id = "custom.lineStyle";
                    value = {
                      fill = "dash";
                      dash = [
                        8
                        6
                      ];
                    };
                  }
                  {
                    id = "custom.fillOpacity";
                    value = 0;
                  }
                ];
              }
            ];
          };
        };
        sabnzbd-servers = {
          order = 131;
          w = 8;
          h = 8;
          panel = g.bargauge {
            title = "News servers";
            description = "What SABnzbd downloaded from each news server over the range";
            unit = "bytes";
            min = 0;
            queries = [
              (g.prom "sum by (server) (increase(sabnzbd_server_downloaded_bytes{${j}}[$__range]))" {
                instant = true;
                legend = "{{server}}";
              })
            ];
          };
        };
      };
    };
    homelab.grafana.drilldown.rows.sabnzbd = {
      workload = "sabnzbd";
      row = rows.drilldown;
    };
  };
}
