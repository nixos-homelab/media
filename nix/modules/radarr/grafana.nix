# Radarr's panels on the Media dashboard and Home, and its row on the Workload dashboard
{ inputs, ... }:
{ config, lib, ... }:
let
  g = inputs.homelab-monitoring.lib.grafana;
  cfg = config.homelab.radarr;
  rows = import ../arr-grafana.nix { inherit g lib; } {
    app = "radarr";
    title = "Radarr";
    missing = "radarr_movie_missing_total";
    downloaded = "radarr_movie_downloaded_total";
    item = "movies";
    order = 12;
  };
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.grafana ];
  options.homelab.radarr.grafana.enable = lib.mkOption {
    description = "Whether the Media and Workload dashboards have Radarr's panels and row.";
    type = lib.types.bool;
    default =
      cfg.enable && cfg.metrics.enable && config.homelab.alloy.enable && config.homelab.grafana.enable;
    defaultText = lib.literalExpression ''
      config.homelab.radarr.enable && config.homelab.radarr.metrics.enable && config.homelab.alloy.enable
      && config.homelab.grafana.enable
    '';
  };
  config = lib.mkIf cfg.grafana.enable {
    homelab.grafana.home.graphs.library = rows.home;
    homelab.grafana.overviews.media = {
      title = "Media";
      description = "The media stack: what's missing, downloading, streaming, and the apps' health";
      panels = rows.tiles // rows.panels;
    };
    homelab.grafana.drilldown.rows.radarr = {
      workload = "radarr";
      row = rows.drilldown;
    };
  };
}
