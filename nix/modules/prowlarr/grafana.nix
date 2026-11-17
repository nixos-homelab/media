# Prowlarr's panels on the Media dashboard and Home, and its row on the Workload dashboard
{ inputs, ... }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  cfg = config.homelab.prowlarr;
  j = ''job="prowlarr"'';
  rows = {
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
          queries = [ (g.prom "max by (indexer) (prowlarr_indexer_unavailable{${j}})" { instant = true; }) ];
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
      panels = {
        prowlarr-indexers = {
          order = 14;
          w = 3;
          h = 4;
          panel = g.ratio {
            title = "Indexers up";
            description = "Prowlarr's enabled indexers it can reach, of all enabled; an unavailable one is backing off after failures";
            good = "sum(prowlarr_indexer_enabled_total{${j}}) - (count(prowlarr_indexer_unavailable{${j}}) or vector(0))";
            all = "sum(prowlarr_indexer_enabled_total{${j}})";
          };
        };
        prowlarr-grabs = {
          order = 120;
          w = 8;
          h = 8;
          panel = g.bargauge {
            title = "Grabs by indexer";
            description = "What each indexer delivered over the range: releases the *arrs grabbed from it";
            decimals = 0;
            queries = [
              (g.prom "sum by (indexer) (increase(prowlarr_indexer_grabs_total{${j}}[$__range]))" {
                instant = true;
                legend = "{{indexer}}";
              })
            ];
          };
        };
        prowlarr-failures = {
          order = 121;
          w = 8;
          h = 8;
          panel = g.timeseries {
            title = "Failed queries";
            description = "Queries that failed, per indexer, as bars: a run of them backs the indexer off, and the Indexers up tile drops";
            decimals = 0;
            noValue = "No failures";
            legend = "right";
            custom = {
              drawStyle = "bars";
              stacking.mode = "normal";
              fillOpacity = 70;
              lineWidth = 0;
            };
            queryOptions.maxDataPoints = 60;
            queries = [
              (g.prom "sum by (indexer) (increase(prowlarr_indexer_failed_queries_total{${j}}[$__interval])) > 0"
                {
                  legend = "{{indexer}}";
                }
              )
            ];
          };
        };
      };
    };
    homelab.grafana.drilldown.rows.prowlarr = {
      workload = "prowlarr";
      row = rows.drilldown;
    };
  };
}
