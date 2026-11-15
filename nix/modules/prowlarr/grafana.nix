# Prowlarr's rows: one on the Media dashboard, one on the Workload dashboard for its namespace
{ inputs, ... }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  cfg = config.homelab.prowlarr;
  j = ''job="prowlarr"'';
  rows = {
    overview = g.row { title = "Prowlarr"; } (
      g.autoGrid { columns = 3; } [
        (g.stat {
          title = "Indexers unavailable";
          decimals = 0;
          queries = [
            (g.prom "count(prowlarr_indexer_unavailable{${j}} == 1) or vector(0)" { instant = true; })
          ];
          thresholds = [
            {
              value = null;
              color = "green";
            }
            {
              value = 1;
              color = "orange";
            }
          ];
        })
        (g.table {
          title = "Unavailable";
          queries = [ (g.prom "prowlarr_indexer_unavailable{${j}} == 1" { instant = true; }) ];
          noValue = "None";
        })
        (g.stat {
          title = "Grabs in range";
          decimals = 0;
          queries = [
            (g.prom "sum(increase(prowlarr_indexer_grabs_total{${j}}[$__range]))" { instant = true; })
          ];
        })
      ]
    );
    drilldown = g.row { title = "Prowlarr"; } (
      g.autoGrid { columns = 2; } [
        (g.timeseries {
          title = "Queries by indexer";
          unit = "short";
          queries = [
            (g.prom "sum by (indexer) (increase(prowlarr_indexer_queries_total{${j}}[$__rate_interval]))" {
              legend = "{{indexer}}";
            })
          ];
        })
        (g.timeseries {
          title = "Failed queries by indexer";
          queries = [
            (g.prom
              "sum by (indexer) (increase(prowlarr_indexer_failed_queries_total{${j}}[$__rate_interval])) > 0"
              {
                legend = "{{indexer}}";
              }
            )
          ];
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
