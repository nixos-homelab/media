# Plex's panels on the Media dashboard and Home, and its row on the Workload dashboard
{ inputs, ... }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  cfg = config.homelab.plex;
  j = ''job="plex"'';
  rows = {
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
          queries = [
            (g.prom "max by (server, version, platform, platform_version) (server_info{${j}})" {
              instant = true;
            })
          ];
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
      panels = {
        plex-plays = {
          order = 17;
          w = 3;
          h = 4;
          panel = g.stat {
            title = "Plex plays";
            description = "Plays Plex counted in the hour before";
            decimals = 0;
            queries = [ (g.prom "sum(increase(plays_total{${j}}[1h])) or vector(0)" { }) ];
          };
        };
        plex-streaming = {
          order = 150;
          w = 8;
          h = 8;
          panel = g.timeseries {
            title = "Plex streaming";
            description = "What Plex sends its players, and on the right axis, dashed, the time they played";
            unit = "bps";
            queries = [
              (g.prom "sum(rate(transmit_bytes_total{${j}}[$__rate_interval])) * 8" { legend = "sent"; })
              (g.prom "sum(rate(play_seconds_total{${j}}[$__rate_interval]))" { legend = "streams playing"; })
            ];
            overrides = [
              {
                matcher = {
                  id = "byName";
                  options = "streams playing";
                };
                properties = [
                  {
                    id = "unit";
                    value = "short";
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
        plex-libraries = {
          order = 151;
          w = 8;
          h = 8;
          panel = g.bargauge {
            title = "Plex libraries";
            description = "The size of each of Plex's libraries on disk";
            unit = "bytes";
            min = 0;
            queries = [
              (g.prom "library_storage_total{${j}}" {
                instant = true;
                legend = "{{library}}";
              })
            ];
          };
        };
      };
    };
    homelab.grafana.drilldown.rows.plex = {
      workload = "plex";
      row = rows.drilldown;
    };
  };
}
