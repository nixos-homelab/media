# Prowlarr's rows: one on the Media dashboard, one on the Workload dashboard for its namespace
{ inputs, ... }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  cfg = config.homelab.prowlarr;
  j = ''job="prowlarr"'';
  # Per indexer, side by side: { A = name; B = name; }
  perIndexer = names: [
    { id = "merge"; }
    {
      id = "organize";
      options = {
        excludeByName = {
          Time = true;
          job = true;
          url = true;
          namespace = true;
          node = true;
          instance = true;
          pod = true;
          container = true;
          endpoint = true;
          service = true;
        };
        renameByName = lib.mapAttrs' (ref: name: lib.nameValuePair "Value #${ref}" name) names;
      };
    }
  ];
  rows = {
    overview = g.row { title = "Prowlarr"; } (
      g.autoGrid { columns = 2; } [
        (g.stat {
          title = "Indexers";
          decimals = 0;
          queries = [
            (g.prom "prowlarr_indexer_total{${j}}" {
              instant = true;
              legend = "configured";
            })
            (g.prom "prowlarr_indexer_enabled_total{${j}}" {
              instant = true;
              legend = "enabled";
            })
            (g.prom "count(prowlarr_indexer_unavailable{${j}}) or vector(0)" {
              instant = true;
              legend = "unavailable";
            })
          ];
        })
        (g.table {
          title = "By indexer";
          description = "In the dashboard's time range; response time is Prowlarr's average";
          queries = [
            (g.prom "sum by (indexer) (increase(prowlarr_indexer_queries_total{${j}}[$__range]))" {
              instant = true;
            })
            (g.prom "sum by (indexer) (increase(prowlarr_indexer_grabs_total{${j}}[$__range]))" {
              instant = true;
            })
            (g.prom "sum by (indexer) (increase(prowlarr_indexer_failed_queries_total{${j}}[$__range]))" {
              instant = true;
            })
            (g.prom "max by (indexer) (prowlarr_indexer_average_response_time_ms{${j}})" { instant = true; })
          ];
          transformations = perIndexer {
            A = "queries";
            B = "grabs";
            C = "failed queries";
            D = "response (ms)";
          };
        })
      ]
    );
    drilldown = g.row { title = "Prowlarr"; } (
      g.autoGrid { columns = 2; } [
        (g.timeseries {
          title = "Queries by indexer";
          queries = [
            (g.prom "sum by (indexer) (increase(prowlarr_indexer_queries_total{${j}}[$__rate_interval]))" {
              legend = "{{indexer}}";
            })
          ];
        })
        (g.timeseries {
          title = "Failed queries by indexer";
          queries = [
            (g.prom "sum by (indexer) (increase(prowlarr_indexer_failed_queries_total{${j}}[$__rate_interval]))"
              {
                legend = "{{indexer}}";
              }
            )
          ];
        })
        (g.table {
          title = "Unavailable";
          description = "The indexers Prowlarr reports as unavailable";
          queries = [ (g.prom "prowlarr_indexer_unavailable{${j}}" { instant = true; }) ];
        })
      ]
    );
  };
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.grafana ];
  options.homelab.prowlarr.grafana.enable = lib.mkOption {
    description = "Whether the Media and Workload dashboards have Prowlarr's rows.";
    type = lib.types.bool;
    default =
      cfg.enable && cfg.metrics.enable && config.homelab.alloy.enable && config.homelab.grafana.enable;
    defaultText = lib.literalExpression ''
      config.homelab.prowlarr.enable && config.homelab.prowlarr.metrics.enable && config.homelab.alloy.enable
      && config.homelab.grafana.enable
    '';
  };
  config = lib.mkIf cfg.grafana.enable {
    homelab.grafana.overviews.media = {
      title = "Media";
      description = "The media stack: what's missing, downloading, streaming, and the apps' health";
      rows.prowlarr = {
        order = 620;
        row = rows.overview;
      };
    };
    homelab.grafana.drilldown.rows.prowlarr = {
      workload = "prowlarr";
      row = rows.drilldown;
    };
  };
}
